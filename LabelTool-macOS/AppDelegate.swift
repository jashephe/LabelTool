import Cocoa
import SwiftUI
import Combine
import Glimmer
import Version
import Defaults

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var updater: GlimmerUpdater = GlimmerUpdater(repositoryOwner: "jashephe", repositoryName: "LabelTool")
    var maybeUpdatedRelease: AnyPublisher<GlimmerRelease, GlimmerError> {
        get {
            self.updater.getLatestRelease().filter { (release) -> Bool in
                if let releaseVersion = Version(release.tag.dropFirst()), releaseVersion > Bundle.main.version {
                    return true
                }
                return false
            }.eraseToAnyPublisher()
        }
    }


    var templatesManager: TemplatesManager!
    var welcomeScreenManager: WelcomeScreenManager!

    var dockMenu: NSMenu!

    private var templatesFolderWatcher: AnyCancellable? = nil

    //MARK: NSApplicationDelegate

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        self.templatesManager = TemplatesManager(templatesDirectory: TemplatesManager.templatesDirectory!)!
        NSFileCoordinator.addFilePresenter(self.templatesManager)

        Defaults.migrate(.labelValues, to: .v5)
        Defaults.migrate(.printers, to: .v5)

        self.welcomeScreenManager = WelcomeScreenManager()

        self.dockMenu = NSMenu()
        self.dockMenu.addItem(NSMenuItem(title: "Labels from template...", action: nil, keyEquivalent: ""))

        self.welcomeScreenManager.showWelcomeScreen()

        self.templatesFolderWatcher = self.templatesManager.currentAvailableTemplates.sink { templateURLs in
            DispatchQueue.main.async {
                self.welcomeScreenManager.setTemplatesList(templates: templateURLs)
                self.updateTemplatesMenus(withTemplateURLs: templateURLs)
            }
        }
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        if SessionsManager.shared.sessions.count <= 0 {
            self.welcomeScreenManager.showWelcomeScreen()
        }
    }

    func applicationWillResignActive(_ notification: Notification) {
        self.welcomeScreenManager.hideWelcomeScreen()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        return self.dockMenu
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        self.templatesManager.importTemplates(at: urls)
    }

    //MARK: Helper Methods

    private static let TEMPLATE_MENUITEM_TAG: Int = 634
    func updateTemplatesMenus(withTemplateURLs templateURLs: [URL]) {
        let labelsMenu = NSApp.mainMenu!.item(withTitle: "Labels")!.submenu!
        for menuItem in labelsMenu.items {
            if menuItem.tag == Self.TEMPLATE_MENUITEM_TAG {
                labelsMenu.removeItem(menuItem)
            }
        }

        for menuItem in dockMenu.items {
            if menuItem.tag == Self.TEMPLATE_MENUITEM_TAG {
                dockMenu.removeItem(menuItem)
            }
        }

        for (index, menuItem) in templateURLs.map({ (templatePath) -> NSMenuItem in
            let item = NSMenuItem(title: templatePath.deletingPathExtension().lastPathComponent, action: #selector(Self.handleTemplateMenuItemSelection(sender:)), keyEquivalent: "")
            item.indentationLevel = 1
            item.representedObject = templatePath
            item.tag = Self.TEMPLATE_MENUITEM_TAG
            return item
        }).enumerated() {
            let mainMenuItem = menuItem
            let dockMenuItem = menuItem.copy() as! NSMenuItem
            labelsMenu.insertItem(mainMenuItem, at: 1 + index)
            dockMenu.insertItem(dockMenuItem, at: 1 + index)
        }
    }

    @objc func handleTemplateMenuItemSelection(sender: Any) {
        if
            let menuItem = sender as? NSMenuItem,
            let labelTemplatePath = menuItem.representedObject as? URL,
            let session = LabelSession(labelTemplatePath: labelTemplatePath)
        {
            SessionsManager.shared.addSession(session)
            self.welcomeScreenManager.hideWelcomeScreen()
        }
    }

    @IBAction func preferencesMenuItemActionHandler(_ sender: NSMenuItem) {
        sharedPreferencesWindowController.show()
    }

    @IBAction func openTemplatesFolder(_ sender: Any) {
        NSWorkspace.shared.open(self.templatesManager.templatesDirectory)
    }
}
