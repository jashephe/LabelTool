import Cocoa
import Combine

class SessionsManager: NSObject, NSWindowDelegate {
    /// The shared `SessionsManager` singleton
    static let shared = SessionsManager()

    private(set) var sessions: [LabelSession] = []

    private var finishedSessions: [LabelSession] = []

    private var windowWatcher: AnyCancellable? = nil

    private override init() {
        super.init()
    }

    func addSession(_ session: LabelSession) {
        session.window.center()
        session.window.makeKeyAndOrderFront(self)
        session.window.delegate = self

        self.sessions.append(session)
        self.finishedSessions = []
    }

    //MARK: `NSWindowDelegate` Methods

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            for (index, session) in self.sessions.enumerated() {
                if session.window == window {
                    self.finishedSessions.append(self.sessions.remove(at: index))
                    break
                }
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.isDocumentEdited {
            let exitConfirmAlert = NSAlert()
            exitConfirmAlert.alertStyle = .warning
            exitConfirmAlert.messageText = "Are you sure?"
            exitConfirmAlert.informativeText = "Any label data entered in this window that has not been printed will be lost."
            exitConfirmAlert.addButton(withTitle: "Close Window")
            exitConfirmAlert.addButton(withTitle: "Cancel")
            exitConfirmAlert.beginSheetModal(for: sender) { response in
                if response == .alertFirstButtonReturn {
                    sender.close()
                }
            }
            return false
        } else {
            return true
        }
    }

    func window(_ window: NSWindow, shouldDragDocumentWith event: NSEvent, from dragImageLocation: NSPoint, with pasteboard: NSPasteboard) -> Bool {
        return false
    }
}
