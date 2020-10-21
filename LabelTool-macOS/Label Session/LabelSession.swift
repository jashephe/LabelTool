import Cocoa
import SwiftUI
import Combine

import Defaults

class LabelSession: ObservableObject {
    var window: NSWindow
    let template: LabelTemplate
    @Published var data: LabelsData
    @Published var renderedLabels: [LabelTemplate.RenderedLabel]

    var possiblePrinters: [String] {
        return Array(Defaults[.printers].keys)
    }
    @Published var selectedPrinterName: String? = nil
    var selectedPrinterConfig: PrinterConfig? = nil

    var processActivity: NSObjectProtocol? = nil

    private var pendingTasks: Set<AnyCancellable> = Set()

    convenience init?(labelTemplatePath: URL) {
        guard
            let templateFile = try? FileHandle(forReadingFrom: labelTemplatePath),
            let labelTemplate: LabelTemplate = try? JSONDecoder().decode(LabelTemplate.self, from: templateFile.availableData)
            else {
                return nil
        }

        self.init(labelTemplate: labelTemplate, labelTemplatePath: labelTemplatePath)
    }

    init(labelTemplate: LabelTemplate, labelTemplatePath: URL?) {
        self.template = labelTemplate
        self.data = LabelsData(template: self.template)
        self.renderedLabels = []

        self.window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)

        self.window.setContentBorderThickness(40, for: .minY)

        if let templateName = labelTemplatePath?.deletingPathExtension().lastPathComponent {
            self.window.title = "\(templateName) Label Designer"
        } else {
            self.window.title = "Label Designer"
        }
        self.window.representedURL = labelTemplatePath
        self.window.isReleasedWhenClosed = false

        Defaults.publisher(.printers).sink { change in
            if change.newValue.count <= 0 {
                self.selectedPrinterName = nil
            } else if self.selectedPrinterName.isNil, let (name, config) = change.newValue.first {
                self.selectedPrinterName = name
                self.selectedPrinterConfig = config
            } else if let selectedPrinterName = self.selectedPrinterName, change.newValue[selectedPrinterName].isNil, let (name, config) = change.newValue.first {
                self.selectedPrinterName = name
                self.selectedPrinterConfig = config
            }
        }.store(in: &self.pendingTasks)

        self.objectWillChange.sink {
            if self.data.count <= 0 {
                self.window.isDocumentEdited = false
                if let processActivity = self.processActivity {
                    ProcessInfo.processInfo.endActivity(processActivity)
                    self.processActivity = nil
                }
            } else {
                self.window.isDocumentEdited = true
                if self.processActivity.isNil {
                    self.processActivity = ProcessInfo.processInfo.beginActivity(options: .suddenTerminationDisabled, reason: "Label Session with unsaved changes")
                }
            }
        }.store(in: &self.pendingTasks)

        let sessionView = LabelSessionView(previewScaleRange: 0.2...2, defaultPreviewScale: 1.0 / (self.window.screen?.backingScaleFactor ?? 1.0)).environmentObject(self)
        let hostingView = NSHostingView(rootView: sessionView)
        self.window.contentView = hostingView
    }

    deinit {
        if let processActivity = self.processActivity {
            ProcessInfo.processInfo.endActivity(processActivity)
        }
    }

    func copyDataHeaderToClipboard() {
        self.data.copyData(toPasteboard: NSPasteboard.general)
    }

    func readDataFromClipboard() {
        self.data.importData(fromPasteboard: NSPasteboard.general)
        self.renderLabels()
    }

    func renderLabels() {
        self.renderedLabels = []
        for i in 0..<self.data.count {
            if case .success(let renderedLabel) = self.template.renderToImage(valueRenderer: self.data.valueRendererWithData(atIndex: i)) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    renderedLabels.append(renderedLabel)
                }
            }
        }
    }

    func printLabels() {
        guard
            let selectedPrinterName = self.selectedPrinterName,
            let printerConfig = Defaults[.printers][selectedPrinterName],
            let printer = try? ZPLPrinter(printerConfig: printerConfig)
        else {
            print("Couldn't initialize printer")
            return
        }

        let zplStrings = self.renderedLabels.map { (renderedLabel) -> String in
            return printer.generateZPLForPrinting(pixelData: renderedLabel.pixelData, width: UInt(renderedLabel.image.width), zplPrefix: "^PW\(self.template.width)")
        }.joined(separator: "\n")

        printer.send(message: zplStrings.data(using: .ascii)!, toEndpoint: printer.printingEndpoint).sink(receiveCompletion: { (completion) in
            print("Completed: \(completion)")
        }) { (responseData) in
            print("Response: \(String(data: responseData, encoding: .ascii) ?? "none")")
        }.store(in: &self.pendingTasks)
    }

    func makePDFDragHandler() -> NSItemProvider {
        let itemProvider = NSItemProvider()
        itemProvider.suggestedName = "labels.pdf"
        itemProvider.registerDataRepresentation(forTypeIdentifier: kUTTypePDF as String, visibility: .all) { (completionHandler) -> Progress? in
            DispatchQueue.global(qos: .userInitiated).async {
                switch renderToPDF(images: self.renderedLabels.map(\.image), dotsPerInch: 300) {
                case .success(let data):
                    completionHandler(data, nil)
                case .failure(let error):
                    completionHandler(nil, error)
                }
            }
            return nil
        }

        return itemProvider
    }
}
