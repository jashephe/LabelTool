import SwiftUI

extension AnyTransition {
    static var peekInTrailing: AnyTransition {
        return AnyTransition.move(edge: .trailing).combined(with: .opacity)
    }
}

struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static var defaultValue: Value = .zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        _ = nextValue()
    }
}

struct DropOverlayView: View {
    @Binding var shouldShow: Bool
    var label: String

    var body: some View {
        Group {
            if self.shouldShow {
                ZStack(alignment: .center) {
                    Text("\(self.label)").font(.system(size: 30, weight: .bold, design: .default)).foregroundColor(Color.accentColor).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }
}

struct SimpleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled: Bool

    let backgroundColor: Color
    let activeBackgroundColor: Color
    let disabledBackgroundColor: Color
    let foregroundColor: Color
    let activeForegroundColor: Color
    let disabledForegroundColor: Color
    let cornerRadius: CGFloat

    init(backgroundColor: Color, activeBackgroundColor: Color, disabledBackgroundColor: Color, foregroundColor: Color, activeForegroundColor: Color, disabledForegroundColor: Color, cornerRadius: CGFloat) {
        self.backgroundColor = backgroundColor
        self.activeBackgroundColor = activeBackgroundColor
        self.disabledBackgroundColor = disabledBackgroundColor
        self.foregroundColor = foregroundColor
        self.activeForegroundColor = activeForegroundColor
        self.disabledForegroundColor = disabledForegroundColor
        self.cornerRadius = cornerRadius
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .foregroundColor(configuration.isPressed ? self.activeForegroundColor : self.foregroundColor)
            .background(configuration.isPressed ? self.activeBackgroundColor : self.backgroundColor)
            .cornerRadius(self.cornerRadius)
    }
}
