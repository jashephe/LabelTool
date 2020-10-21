import SwiftUI

struct LabelSessionRenderView: View {
    @EnvironmentObject var session: LabelSession

    @Binding var previewScale: CGFloat

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .center, spacing: 10) {
                ForEach(self.session.renderedLabels, id: \.image) { renderedLabel in
                    LabelPreviewView(labelImage: renderedLabel.image, warnings: renderedLabel.warnings, labelScale: self.$previewScale).transition(.asymmetric(insertion: .scale, removal: .identity))
                }
            }.padding(.vertical, 10)
            .onDrag {
                return self.session.makePDFDragHandler()
            }
        }
        .overlay(Group {
            if self.session.renderedLabels.count <= 0 {
                Text("No Labels").foregroundColor(.secondary).padding(15).background(Color("notificationBackground").opacity(0.5)).cornerRadius(5).transition(.opacity)
            }
        })
        .frame(minWidth: 200, minHeight: 100, alignment: .center)
    }
}

struct LabelPreviewView: View {
    var labelImage: CGImage
    var warnings: [LabelTemplate.Warning]
    @Binding var labelScale: CGFloat

    @State var errorPopupVisible: Bool = false
    private let borderWidth: CGFloat = 2

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            if self.warnings.count > 0 {
                Button(action: {
                    self.errorPopupVisible = true
                }) {
                    Image("warning").resizable().frame(width: 22, height: 22).fixedSize().foregroundColor(Color("warning")).shadow(radius: 2)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 25, height: 25, alignment: .center)
                .padding(.horizontal, 5)
                .popover(isPresented: self.$errorPopupVisible, arrowEdge: .leading) {
                    HStack(spacing: 0) {
                        Image("warning").resizable().foregroundColor(Color("warning")).frame(width: 22, height: 22).fixedSize().shadow(radius: 2)
                            .padding(.vertical, 20)
                            .padding(.horizontal, 10)
                        Divider()
                        VStack(spacing: 5) {
                            ForEach(0..<self.warnings.count) { (i) in
                                VStack(alignment: .leading) {
                                    Text(self.warnings[i].name)
                                        .font(.system(size: 11, weight: .semibold, design: .default))
                                    Text(self.warnings[i].description)
                                        .font(.system(size: 10, weight: .regular, design: .default))
                                }
                                .frame(maxWidth: 250)
                            }
                        }
                        .padding(5)
                    }
                }
            }

            Image(self.labelImage, scale: 1, label: Text("label preview"))
                .resizable(resizingMode: .stretch)
                .interpolation(.none)
                .shadow(radius: 2)
                .border(Color("warning"), width: self.warnings.count > 0 ? self.borderWidth : 0)
                .frame(width: CGFloat(self.labelImage.width)*self.labelScale, height: CGFloat(self.labelImage.height)*self.labelScale, alignment: .center)
            if self.warnings.count > 0 {
                Spacer(minLength: 25)
                    .frame(width: 25, height: 25, alignment: .center)
                    .padding(.horizontal, 5)
            }
        }
    }
}
