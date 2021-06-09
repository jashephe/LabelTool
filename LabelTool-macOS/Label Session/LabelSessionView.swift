import SwiftUI
import Defaults

struct LabelSessionView: View {
    @EnvironmentObject var session: LabelSession
    let previewScaleRange: ClosedRange<CGFloat>
    let defaultPreviewScale: CGFloat

    @State private var isDroppingData: Bool = false
    @State private var previewScale: CGFloat = 1.0
    @State private var lastPreviewScale: CGFloat = 1.0
    @State private var showPrinterChooser: Bool = false

    @State private var showHelp: Bool = false

    private var previewScaleGesture: some Gesture {
        return MagnificationGesture(minimumScaleDelta: 0).onChanged({ (value) in
            let delta = value/self.lastPreviewScale
            self.lastPreviewScale = value
            self.previewScale = (self.previewScale * delta).clamped(to: self.previewScaleRange)
        }).onEnded({ (value) in
            self.lastPreviewScale = 1.0
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                LabelSessionDataView().onDrop(of: [kUTTypeUTF8PlainText as String, kUTTypeFileURL as String], isTargeted: self.$isDroppingData) { (itemProviders) -> Bool in
                    if let itemProvider = itemProviders.first {
                        if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeUTF8PlainText as String) {
                            itemProvider.loadItem(forTypeIdentifier: kUTTypeUTF8PlainText as String, options: nil) { (item, error) in
                                if let data = item as? Data, let value = String(data: data, encoding: .utf8) {
                                    DispatchQueue.main.async {
                                        self.session.data.importData(fromDelimited: value)
                                        self.session.renderLabels()
                                    }
                                }
                            }
                            return true
                        } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                            itemProvider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil) { (item, error) in
                                if let data = item as? Data, let fileURL = URL(dataRepresentation: data, relativeTo: nil) {
                                    DispatchQueue.main.async {
                                        self.session.data.importData(fromFile: fileURL)
                                        self.session.renderLabels()
                                    }
                                }
                            }
                            return true
                        }
                    }
                    return false
                }.overlay(DropOverlayView(shouldShow: self.$isDroppingData, label: "Import")).popover(isPresented: self.$showHelp, arrowEdge: .leading) {
                    VStack(alignment: .leading) {
                        Text("Enter label data").font(.system(size: 12, weight: .bold, design: .default))
                        Text("You can drag and drop tab-separated text or a TSV file.").font(.system(size: 10, weight: .regular, design: .default))
                    }.frame(width: 200, alignment: .leading).padding(10)
                }
                LabelSessionRenderView(previewScale: self.$previewScale).gesture(self.previewScaleGesture).popover(isPresented: self.$showHelp, arrowEdge: .trailing) {
                    VStack(alignment: .leading) {
                        Text("Label Preview").font(.system(size: 12, weight: .bold, design: .default))
                        Text("Rendered labels are displayed here, one for each line in the label data table.").font(.system(size: 10, weight: .regular, design: .default))
                    }.frame(width: 200, alignment: .leading).padding(10)
                }
            }
            HStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button(action: {
                        self.session.window.close()
                    }) {
                        Text("Cancel")
                    }
                    Divider()
                }

                HStack(spacing: 5) {
                    Button(action: {
                        withAnimation {
                            self.session.data.clear()
                            self.session.renderLabels()
                        }
                    }) {
                        Image(systemName: "delete.left").font(.system(size: 16, weight: .regular))
                    }.buttonStyle(PlainButtonStyle())
                    Button(action: {
                        self.showHelp.toggle()
                    }) {
                        Image(systemName: "questionmark.circle").font(.system(size: 16, weight: .regular))
                    }.buttonStyle(PlainButtonStyle())
                    Spacer()
                    Text("\(self.session.data.count) label\(self.session.data.count != 1 ? "s" : "")").fixedSize()
                    Spacer()
                    Slider(value: self.$previewScale, in: self.previewScaleRange) {
                        Button(action: {
                            self.previewScale = self.defaultPreviewScale
                        }) {
                            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .regular))
                        }.buttonStyle(PlainButtonStyle())
                    }.onAppear(perform: {
                        self.previewScale = self.defaultPreviewScale
                    })
                    .frame(width: 120)
                }.padding(.horizontal)
                HStack(spacing: 10) {
                    Divider()
                    Button(action: {
                        self.showPrinterChooser = true
                    }) {
                        Image(systemName: "printer").font(.system(size: 16, weight: .regular)).foregroundColor(self.session.selectedPrinterName.isNil ? Color.red : Color.primary)
                    }.buttonStyle(PlainButtonStyle()).popover(isPresented: self.$showPrinterChooser, arrowEdge: .bottom) {
                        if self.session.possiblePrinters.count > 0 {
                            VStack {
                                Picker("Printer", selection: self.$session.selectedPrinterName) {
                                    ForEach(self.session.possiblePrinters.sorted(), id: \.self) { printerName in
                                        Text(printerName).tag(printerName as String?)
                                    }
                                }.labelsHidden().frame(minWidth: 100, maxWidth: 150).padding([.horizontal, .top], 10)
                                if let selectedPrinterName = self.session.selectedPrinterName {
                                    Divider()
                                    Text(selectedPrinterName)
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                Text("No printers configured.").fontWeight(.bold).padding(10)
                                Divider()
                                Button(action: {
                                    sharedPreferencesWindowController.show(preferencePane: .printers)
                                }) {
                                    Text("Add a Printer").keyboardShortcut(.defaultAction)
                                }.padding(10)
                            }
                        }
                    }
                    Button(action: {
                        self.session.printLabels()
                    }) {
                        Text("Print")
                    }.disabled(self.session.data.count <= 0 || self.session.selectedPrinterName.isNil).onTapGesture {
                        if self.session.selectedPrinterName.isNil {
                            self.showPrinterChooser = true
                        }
                    }.keyboardShortcut(.defaultAction)
                }
            }.frame(height: 40).frame(maxWidth: .infinity).padding(.horizontal, 10)
        }
    }
}
