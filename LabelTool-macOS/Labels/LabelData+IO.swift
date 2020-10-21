import AppKit

extension LabelsData {
    mutating func importData(fromPasteboard pasteboard: NSPasteboard) {
        for pasteboardItem in pasteboard.pasteboardItems ?? [] {
            if let pasteboardValue = pasteboardItem.string(forType: .string) {
                self.importData(fromDelimited: pasteboardValue)
            }
        }
    }

    func copyData(toPasteboard pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let descriptors = self.fieldDescriptors.filter({ $0.type == .userDefined })
        var contents = descriptors.map(\.name).joined(separator: "\t")
        for index in 0..<self.count {
            contents += "\n" + descriptors.map({ self.value(atIndex: index, withDescriptor: $0) ?? "" }).joined(separator: "\t")
        }
        pasteboard.setString(contents, forType: .string)
    }

    mutating func importData(fromFile path: URL) {
        if let fileContents = try? String(contentsOf: path, encoding: .utf8) {
            self.importData(fromDelimited: fileContents)
        }
    }
}
