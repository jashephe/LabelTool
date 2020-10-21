import Cocoa
import SwiftUI

struct LabelSessionDataView: View {
    @EnvironmentObject var session: LabelSession

    var body: some View {
        LabelsDataTable().frame(minWidth: 200, minHeight: 100, alignment: .center)
    }
}

private extension NSUserInterfaceItemIdentifier {
    static let textCell = Self("textCell")
}

struct LabelsDataTable: NSViewControllerRepresentable {
    @EnvironmentObject var session: LabelSession
    @Environment(\.isEnabled) var isEnabled

    typealias NSViewControllerType = LabelsDataTableViewController
    typealias Coordinator = LabelsDataTableCoordinator

    func makeNSViewController(context: Context) -> LabelsDataTableViewController {
        let viewController = LabelsDataTableViewController(session: self.session)
        viewController.tableView.delegate = context.coordinator
        viewController.tableView.dataSource = context.coordinator
        return viewController
    }

    func makeCoordinator() -> LabelsDataTableCoordinator {
        return LabelsDataTableCoordinator(data: self.session.data)
    }

    func updateNSViewController(_ nsViewController: LabelsDataTableViewController, context: Context) {
        nsViewController.tableView.isEnabled = self.isEnabled
        nsViewController.tableView.reconcileColumns(newColumnNames: self.session.data.fieldDescriptors.map(String.init))
        context.coordinator.reloadData(self.session.data)
        nsViewController.tableView.reloadData()
    }

    class LabelsDataTableViewController: NSViewController {
        var session: LabelSession
        let tableView: NSTableView = NSTableView()

        init(session: LabelSession) {
            self.session = session
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            self.tableView.autoresizingMask = [.height, .width]
            self.tableView.allowsColumnReordering = true
            self.tableView.allowsColumnResizing = true
            self.tableView.allowsEmptySelection = true
            self.tableView.allowsColumnSelection = false
            self.tableView.usesAlternatingRowBackgroundColors = true
            self.tableView.selectionHighlightStyle = .none
            self.tableView.columnAutoresizingStyle = .sequentialColumnAutoresizingStyle

            let scrollView = NSScrollView()
            scrollView.drawsBackground = false
            scrollView.documentView = self.tableView
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autoresizingMask = [.height, .width]
            scrollView.borderType = .noBorder

            self.view = scrollView
        }

        @objc func copy(_ sender: AnyObject) {
            session.copyDataHeaderToClipboard()
        }

        @objc func paste(_ sender: AnyObject) {
            session.readDataFromClipboard()
        }
    }

    class LabelsDataTableCoordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        var data: LabelsData

        init(data: LabelsData) {
            self.data = data
        }

        func reloadData(_ data: LabelsData) {
            self.data = data
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            return Int(self.data.count)
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let textField: NSTextField = tableView.makeView(withIdentifier: .textCell, owner: self) as? NSTextField ?? { () -> NSTextField in
                let aTextField = NSTextField()
                aTextField.isBordered = false
                aTextField.backgroundColor = nil
                aTextField.identifier = .textCell
                aTextField.isEditable = false
                aTextField.lineBreakMode = .byTruncatingTail
                return aTextField
            }()
            return textField
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            if let columnKey = tableColumn?.identifier.rawValue, let columnDescriptor = LabelFieldDescriptor(string: columnKey) {
                return self.data.value(atIndex: UInt(row), withDescriptor: columnDescriptor)
            }
            return nil
        }
    }
}

private extension NSTableView {
    func reconcileColumns(newColumnNames: [String]) {
        var columnNamesToAdd = newColumnNames

        for column in self.tableColumns {
            if let wantedColumnIndex = columnNamesToAdd.firstIndex(of: column.identifier.rawValue) {
                columnNamesToAdd.remove(at: wantedColumnIndex)
            } else {
                self.removeTableColumn(column)
            }
        }

        for columnName in columnNamesToAdd {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: columnName))
            column.title = columnName
            column.sizeToFit()
            column.minWidth = max(column.width, 50)
            self.addTableColumn(column)
        }
    }
}
