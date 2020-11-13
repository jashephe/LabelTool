import AppKit
import SwiftUI
import Combine

class TemplatesManager: NSObject, NSFilePresenter {
    static var templatesDirectory: URL? {
        guard let suiteName = Config.suiteName else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?.appendingPathComponent("templates", isDirectory: true)
    }

    //MARK: Implementation

    let templatesDirectory: URL
    var currentAvailableTemplates: AnyPublisher<[URL], Never> {
        return self._currentAvailableTemplates.eraseToAnyPublisher()
    }
    private var _currentAvailableTemplates: CurrentValueSubject<[URL], Never>

    init?(templatesDirectory: URL) {
        self.templatesDirectory = templatesDirectory
        try? FileManager.default.createDirectory(at: self.templatesDirectory, withIntermediateDirectories: true, attributes: nil)
        self._currentAvailableTemplates = CurrentValueSubject(Self.availableTemplates(inDirectory: self.templatesDirectory))
    }

    private static func availableTemplates(inDirectory templatesDirectory: URL) -> [URL] {
        let directoryContents = try? FileManager.default.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: [], options: .skipsHiddenFiles)
        return directoryContents ?? []
    }

    func importTemplates(at paths: [URL]) {
        let importAlert = NSAlert()
        importAlert.alertStyle = .informational
        importAlert.messageText = "Import Templates"
        importAlert.informativeText = "To import a template, move the template file to the templates folder."
        importAlert.addButton(withTitle: "Open Templates Folder")
        switch importAlert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(self.templatesDirectory)
        default:
            break
        }
    }

    //MARK: `NSFilePresenter` Conformance

    var presentedItemURL: URL? {
        self.templatesDirectory
    }
    var presentedItemOperationQueue: OperationQueue = OperationQueue()

    func presentedItemDidChange() {
        self._currentAvailableTemplates.value = Self.availableTemplates(inDirectory: self.templatesDirectory)
    }
}
