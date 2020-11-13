import Cocoa
import SwiftUI
import Combine
import Glimmer
import os.log

class WelcomeScreenManager: ObservableObject {
    var window: NSWindow
    @Published fileprivate var templates: [URL] = []
    @Published var availableUpdate: GlimmerRelease? = nil
    var updateCheckAction: AnyCancellable? = nil

    init() {
        self.window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = appName()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]

        let contentView = WelcomeScreen().environmentObject(self)
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView

        self.updateCheckAction = (NSApp.delegate as! AppDelegate).maybeUpdatedRelease.receive(on: DispatchQueue.main).sink { (completion) in
            switch completion {
            case .finished:
                break
            case .failure(let error):
                os_log("An error occurred while checking for updates: %@", log: OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "update"), String(describing: error))
            }
        } receiveValue: { (release) in
            self.availableUpdate = release
        }

    }

    deinit {
        self.window.close()
    }

    func showWelcomeScreen() {
        self.window.center()
        self.window.makeKeyAndOrderFront(self)
    }

    func hideWelcomeScreen() {
        self.window.orderOut(self)
    }

    func setTemplatesList(templates: [URL]) {
        self.templates = templates
    }

    func openTemplate(_ labelTemplatePath: URL) {
        if let session = LabelSession(labelTemplatePath: labelTemplatePath) {
            SessionsManager.shared.addSession(session)
            self.hideWelcomeScreen()
        }
    }
}

private struct WelcomeScreen: View {
    @EnvironmentObject private var manager: WelcomeScreenManager

    private let listButtonStyle = SimpleButtonStyle(backgroundColor: Color("controlBackground"), activeBackgroundColor: Color.accentColor, disabledBackgroundColor: Color.gray, foregroundColor: Color.accentColor, activeForegroundColor: Color.white, disabledForegroundColor: Color.black, cornerRadius: 0)

    @State private var showNewTemplateInfo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 100, height: 100).fixedSize()
                VStack(spacing: 5) {
                    Text(appName()).font(.system(size: 32, weight: .bold, design: .default)).fixedSize()
                    if let availableUpdate = manager.availableUpdate {
                        Button {
                            NSWorkspace.shared.open(availableUpdate.webURL)
                        } label: {
                            Text("Update Available").underline()
                        }.buttonStyle(PlainButtonStyle()).foregroundColor(Color.blue).font(.system(size: 12, weight: .semibold, design: .default)).fixedSize().onHover { isInside in
                            if isInside {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            }.padding([.horizontal, .top], 5).padding(.bottom, 10)
            Text("New labels from template...").font(.system(size: 10, weight: .bold, design: .default)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 5)
            Divider()
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(self.manager.templates, id: \.self) { templateURL in
                        Button(action: {
                            self.manager.openTemplate(templateURL)
                        }) {
                            HStack(spacing: 0) {
                                Text("\(templateURL.deletingPathExtension().lastPathComponent)")
                                Spacer()
                                Image("right").resizable().frame(width: 22, height: 22).fixedSize()
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }.buttonStyle(self.listButtonStyle)
                    }
                }.frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity, alignment: .top).background(Color("controlBackground"))
            }.frame(height: 100).frame(maxWidth: .infinity, alignment: .top)
            Divider()
            HStack(spacing: 15) {
                Button(action: {
                    (NSApp.delegate as! AppDelegate).templatesManager.importTemplates(at: [])
                }) {
                    Text("Import template...")
                }
                Button(action: {

                }) {
                    Text("New template...")
                }.disabled(true).onTapGesture {
                    self.showNewTemplateInfo.toggle()
                }.popover(isPresented: self.$showNewTemplateInfo, arrowEdge: .bottom) {
                    VStack(alignment: .leading) {
                        Text("Not Available").fontWeight(.bold)
                        Text("A graphical template designer will be included in a future version of this software.").multilineTextAlignment(.leading).frame(width: 280, alignment: .leading)
                    }.padding(5)
                }
            }.padding(5)
        }
    }
}

private func appName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as! String
}
