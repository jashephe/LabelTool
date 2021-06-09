import SwiftUI

import Defaults
import Preferences

extension Preferences.PaneIdentifier {
    static let general = Self("general")
    static let printers = Self("printers")
}

var sharedPreferencesWindowController = PreferencesWindowController(
    panes: [
        Preferences.Pane(identifier: .general, title: "General", toolbarIcon: NSImage(systemSymbolName: "gear", accessibilityDescription: nil)!) { GeneralPreferencesView() },
        Preferences.Pane(identifier: .printers, title: "Printers", toolbarIcon: NSImage(systemSymbolName: "printer", accessibilityDescription: nil)!) { PrinterPreferencesView() }
    ]
)

private struct GeneralPreferencesView: View {
    @Default(.labelValues) var labelValues: [String: String]

    @State var showRemoveButtons: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Default Values").font(.system(size: 16, weight: .bold, design: .default))
                    Spacer()
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.showRemoveButtons.toggle()
                        }
                    }) {
                        Text(self.showRemoveButtons ? "Done" : "Edit").font(.system(size: 12, weight: .light, design: .default))
                    }.foregroundColor(Color.accentColor).buttonStyle(PlainButtonStyle()).animation(.none).disabled(self.labelValues.count <= 0)
                }
                KeyValueView(dictionary: self.$labelValues, showRemoveButtons: self.$showRemoveButtons).frame(minWidth: 300, maxWidth: 450)
                Text("Changes will only take effect for new labels.").foregroundColor(Color.secondary).font(.system(size: 10))
            }.padding()
        }
    }
}

private struct PrinterPreferencesView: View {
    @Default(.printers) var printers: [String: PrinterConfig]
    @State private var addPrinterPopupVisible: Bool = false
    @State var showRemoveButtons: Bool = false

    @State private var newPrinterNickname: String = ""
    @State private var newPrinterHostname: String = ""
    @State private var newPrinterPrintingPort: String = "9100"
    @State private var newPrinterControlPort: String = "9200"

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Printers").font(.system(size: 16, weight: .bold, design: .default))
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.showRemoveButtons.toggle()
                    }
                }) {
                    Text(self.showRemoveButtons ? "Done" : "Edit").font(.system(size: 12, weight: .light, design: .default))
                }.foregroundColor(Color.accentColor).buttonStyle(PlainButtonStyle()).animation(.none).disabled(self.printers.count <= 0)
            }
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(self.printers.keys.sorted(), id: \.self) { printerNickname in
                        HStack(spacing: 0) {
                            PrinterConfigView(printerNickname: printerNickname, printerConfig: self.printers[printerNickname]!)
                            Spacer()
                            if self.showRemoveButtons {
                                Button(action: {
                                    self.printers.removeValue(forKey: printerNickname)
                                    self.showRemoveButtons = false
                                }) {
                                    Image(systemName: "minus.circle").font(.system(size: 16, weight: .regular))
                                }.foregroundColor(Color.red).buttonStyle(PlainButtonStyle()).padding(.horizontal, 5).transition(.peekInTrailing)
                            }
                        }
                    }
                }.padding(5)
            }.frame(minWidth: 300, maxWidth: 450, minHeight: 150, maxHeight: 250, alignment: .top).background(Color("controlBackground")).border(Color("controlBorder"), width: 1)
            Button(action: {
                self.newPrinterNickname = ""
                self.newPrinterHostname = ""
                self.newPrinterPrintingPort = "9100"
                self.newPrinterControlPort = "9200"
                self.addPrinterPopupVisible = true
            }) {
                Image(systemName: "plus.circle").font(.system(size: 16, weight: .regular))
            }
            .foregroundColor(Color.accentColor)
            .buttonStyle(PlainButtonStyle())
            .popover(isPresented: self.$addPrinterPopupVisible) {
                VStack(alignment: .trailing, spacing: 10) {
                    LazyVGrid(columns: [GridItem(.flexible(maximum: 80), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 5, content: {
                        Text("Nickname").font(.system(size: 12, weight: .bold, design: .default))
                        TextField("nickname", text: self.$newPrinterNickname)
                        Text("Hostname").font(.system(size: 12, weight: .bold, design: .default))
                        TextField("hostname", text: self.$newPrinterHostname)
                        Text("Print Port").font(.system(size: 12, weight: .bold, design: .default))
                        TextField("print port", text: self.$newPrinterPrintingPort)
                        Text("Control Port").font(.system(size: 12, weight: .bold, design: .default))
                        TextField("control port", text: self.$newPrinterControlPort)
                    })
                    Button(action: {
                        if let hostname = URL(string: self.newPrinterHostname), let printPort = UInt16(self.newPrinterPrintingPort), let controlPort = UInt16(self.newPrinterControlPort) {
                            let newPrinterConfig = PrinterConfig(hostname: hostname, printPort: printPort, jsonControlPort: controlPort)
                            self.printers[self.newPrinterNickname] = newPrinterConfig
                            self.addPrinterPopupVisible = false
                        }
                    }) {
                        Text("Add")
                    }.keyboardShortcut(.defaultAction)
                }.padding(10).frame(minWidth: 300)
            }
            .padding(.leading, 5)
            .frame(maxWidth: .infinity, alignment: .trailing)

        }.frame(minWidth: 250, minHeight: 100).padding()
    }
}

struct KeyValueView: View {
    @Binding var dictionary: [String : String]
    @Binding var showRemoveButtons: Bool

    @State private var newKey: String = ""
    @State private var newValue: String = ""
    private var enableAddButton: Bool {
        return self.newKey.count > 0 && self.newValue.count > 0
    }

    private var keys: [String] {
        return self.dictionary.keys.sorted()
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            ForEach(self.keys, id: \.self) { key in
                HStack(spacing: 0) {
                    Text("$")
                    Text("\(key)")
                    Text(" : ")
                    TextField("value", text: .constant(self.dictionary[key] ?? "")).disabled(true)
                    if self.showRemoveButtons {
                        Button(action: {
                            self.dictionary.removeValue(forKey: key)
                            self.showRemoveButtons = false
                        }) {
                            Image(systemName: "minus.circle").font(.system(size: 16, weight: .regular))
                        }.foregroundColor(Color.red).buttonStyle(PlainButtonStyle()).padding(.leading, 5).transition(.peekInTrailing)
                    }
                }
            }
            if self.dictionary.count > 0 {
                Divider()
            }
            HStack(spacing: 0) {
                Text("$")
                TextField("key", text: self.$newKey)
                Text(" : ")
                TextField("value", text: self.$newValue)
                Button(action: {
                    self.dictionary[self.newKey] = self.newValue
                    self.newKey = ""
                    self.newValue = ""
                    self.showRemoveButtons = false
                }) {
                    Image(systemName: "plus.circle").font(.system(size: 16, weight: .regular))
                }.foregroundColor(Color.accentColor).buttonStyle(PlainButtonStyle()).padding(.leading, 5).disabled(!self.enableAddButton)
            }
        }.padding().background(Color("controlBackground")).border(Color("controlBorder"), width: 1)
    }
}

struct PrinterConfigView: View {
    var printerNickname: String
    var printerConfig: PrinterConfig

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "printer").font(.system(size: 20, weight: .regular)).padding(5)
            VStack(alignment: .leading) {
                Text("\(self.printerNickname)").font(.system(size: 16, weight: .bold, design: .default)).lineLimit(1)
                HStack(spacing: 0) {
                    Text("\(self.printerConfig.hostname)").font(.system(size: 12, weight: .regular, design: .monospaced)).lineLimit(1)
                    Text(" (")
                    Text(":\(String(self.printerConfig.printPort))").font(.system(size: 12, weight: .regular, design: .monospaced)).lineLimit(1)
                    Text(", ").font(.system(size: 12, weight: .regular, design: .default))
                    Text(":\(String(self.printerConfig.jsonControlPort))").font(.system(size: 12, weight: .regular, design: .monospaced)).lineLimit(1)
                    Text(")")
                }
            }
        }
    }
}
