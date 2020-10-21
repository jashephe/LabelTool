import SwiftUI

struct FileChooser: View {
    var canChooseDirectories: Bool = false
    var windowForModal: NSWindow? = nil
    @Binding var selectedPath: URL?

    @State private var buttonSize: CGSize = CGSize(width: 22, height: 22)
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            GeometryReader { geometryProxy in
                Button(action: {
                    let openPanel = NSOpenPanel();

                    openPanel.title = "Open";
                    openPanel.showsResizeIndicator = true;
                    openPanel.showsHiddenFiles = false;
                    openPanel.canChooseFiles = !self.canChooseDirectories
                    openPanel.canChooseDirectories = self.canChooseDirectories;
                    openPanel.canCreateDirectories = self.canChooseDirectories;
                    openPanel.allowsMultipleSelection = false;

                    let modalCompletionHandler: (NSApplication.ModalResponse) -> Void = { (modalResponse) in
                        if case .OK = modalResponse {
                            self.selectedPath = openPanel.url
                        }
                    }

                    if let window = self.windowForModal {
                        openPanel.beginSheetModal(for: window, completionHandler: modalCompletionHandler)
                    } else {
                        openPanel.begin(completionHandler: modalCompletionHandler)
                    }
                }) {
                    Text("Choose \(self.canChooseDirectories ? "folder" : "file")").frame(maxWidth: 100, alignment: .leading)
                }.preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }.onPreferenceChange(SizePreferenceKey.self) { (preference) in
                self.buttonSize = preference
            }
            HStack(alignment: .center, spacing: 0) {
                self.selectedPath.map { path in
                    return Image(nsImage: NSWorkspace.shared.icon(forFile: path.path)).resizable().frame(maxWidth: self.buttonSize.height, maxHeight: self.buttonSize.height, alignment: .center).fixedSize().padding(.trailing, 4)
                }
                Text(self.labelText).truncationMode(.tail).allowsTightening(true)
            }
        }.onDrop(of: [(kUTTypeFileURL as String)], isTargeted: nil) { (itemProviders) -> Bool in
            if let itemProvider = itemProviders.first {
                if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                    itemProvider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { (item, error) in
                        if let data = item as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) {
                            DispatchQueue.main.async {
                                self.selectedPath = fileURL
                            }
                        }
                    }
                    return true
                }
            }
            return false
        }
    }
    
    var labelText: String {
        get {
            if let selectedPath = self.selectedPath {
                return selectedPath.lastPathComponent
            } else {
                return "No file chosen"
            }
        }
    }
}
