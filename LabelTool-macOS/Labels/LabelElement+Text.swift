import AppKit

struct TextElement: ResizableLabelElement & OrientableLabelElement {
    var x: Int
    var y: Int
    var width: UInt
    var height: UInt
    var valuePrototype: String
    var alignment: TextAlignment {
        get {
            return self._alignment ?? TextAlignment(horizontal: .left, vertical: .middle)
        }
        set(newAlignment) {
            self._alignment = newAlignment
        }
    }
    private var _alignment: TextAlignment?
    var rotation: Float {
        get {
            return self._rotation ?? 0
        }
        set(newRotation) {
            self._rotation = newRotation
        }
    }
    private var _rotation: Float?

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case x
        case y
        case width
        case height
        case valuePrototype = "value"
        case _alignment = "alignment"
        case _rotation = "rotation"
    }

    // MARK: Associated Types

    struct TextAlignment: Codable {
        let horizontal: Horizontal
        let vertical: Vertical

        enum Horizontal {
            case left
            case center
            case right
        }

        enum Vertical {
            case top
            case middle
            case bottom
        }

        init(horizontal: Horizontal, vertical: Vertical) {
            self.horizontal = horizontal
            self.vertical = vertical
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let alignment = try container.decode(String.self)
            switch alignment {
            case "leftTop", "top":
                self = TextAlignment(horizontal: .left, vertical: .top)
            case "leftMiddle", "middle", "left":
                self = TextAlignment(horizontal: .left, vertical: .middle)
            case "leftBottom", "bottom":
                self = TextAlignment(horizontal: .left, vertical: .bottom)
            case "centerTop":
                self = TextAlignment(horizontal: .center, vertical: .top)
            case "centerMiddle", "center":
                self = TextAlignment(horizontal: .center, vertical: .middle)
            case "centerBottom":
                self = TextAlignment(horizontal: .center, vertical: .bottom)
            case "rightTop":
                self = TextAlignment(horizontal: .right, vertical: .top)
            case "rightMiddle", "right":
                self = TextAlignment(horizontal: .right, vertical: .middle)
            case "rightBottom":
                self = TextAlignment(horizontal: .right, vertical: .bottom)
            default:
                throw LabelFileError.unknownType(alignment)
            }
        }


        func encode(to encoder: Encoder) throws {
            //FIXME: Implement
        }
    }

    //MARK: Implementation

    private var frame: CGRect {
        return CGRect(x: self.x, y: self.y, width: Int(self.width), height: Int(self.height))
    }

    private var bounds: CGRect {
        return CGRect(x: 0, y: 0, width: Int(self.width), height: Int(self.height))
    }

    func render(inContext context: CGContext, valueRenderer: (String) -> String) -> [LabelTemplate.Warning] {
        var warnings: [LabelTemplate.Warning] = []

        let adjustedValue = valueRenderer("<body>\(self.valuePrototype)</body>" + #"<style type="text/css">body { font-family: Helvetica; font-size: 20px; }</style>"#)

        var attributedValueToRender = NSMutableAttributedString(string: adjustedValue)
        if let rawData = adjustedValue.data(using: .utf16) { // Apparently NSAttributedString wants UTF-16?
            if let attributedValue = NSAttributedString(html: rawData, documentAttributes: nil) {
                attributedValueToRender = NSMutableAttributedString(attributedString: attributedValue)
            } else {
                warnings.append(.invalidValue(value: adjustedValue, reason: "could not parse HTML data"))
            }
        } else {
            warnings.append(.invalidValue(value: adjustedValue, reason: "element value is not convertible to utf-8 data"))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        switch self.alignment.horizontal {
        case .left:
            paragraphStyle.alignment = .left
        case .center:
            paragraphStyle.alignment = .center
        case .right:
            paragraphStyle.alignment = .right
        }
        attributedValueToRender.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedValueToRender.length))


        let framesetter = CTFramesetterCreateWithAttributedString(attributedValueToRender)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath.init(rect: self.bounds, transform: nil), nil)

        let lineCount = CFArrayGetCount(CTFrameGetLines(frame))
        var lineOrigins: [CGPoint] = Array(repeating: CGPoint(x: -1, y: -1), count: lineCount)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: lineCount), &lineOrigins)
        let renderedHeight: CGFloat? = lineOrigins.last.map({ self.bounds.height - $0.y })

        let fullRange = CTFrameGetStringRange(frame)
        let visibleRange = CTFrameGetVisibleStringRange(frame)
        if fullRange.location != visibleRange.location || fullRange.length != visibleRange.length {
            warnings.append(.textTruncated(fieldIdentifier: "\(attributedValueToRender.string.prefix(5))…", hiddenCharacters: UInt(fullRange.length - visibleRange.length)))
        }

        context.translateBy(x: CGFloat(self.x), y: CGFloat(self.y))
        context.rotate(by: CGFloat(degreesToRadians(self.rotation)))

        switch self.alignment.vertical {
        case .top:
            break
        case .middle:
            if let renderedHeight = renderedHeight {
                context.translateBy(x: 0, y: -CGFloat((Int(self.height) - Int(renderedHeight))/2))
            }
        case .bottom:
            if let renderedHeight = renderedHeight {
                context.translateBy(x: 0, y: -CGFloat((Int(self.height) - Int(renderedHeight))))
            }
        }

        CTFrameDraw(frame, context)

        return warnings
    }
}
