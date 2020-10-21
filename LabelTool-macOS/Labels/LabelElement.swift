import Foundation

// MARK: Label Element Protocols

protocol LabelElement: Codable {
    var x: Int { get set }
    var y: Int { get set }
    
    var valuePrototype: String { get set }

    /// Draw the label element in the given `CGContext`
    /// - Parameter context: the `CGContext` into which the label will be rendered
    /// - Parameter valueRenderer: a function that preprocesses `valuePrototype` in some way before rendering (e.g. to substitute field values)
    /// - Parameter valuePrototype: a `String` that contains the prototype of the field's value, which may be modified in some way before rendering
    func render(inContext context: CGContext, valueRenderer: (_ valuePrototype: String) -> String) -> [LabelTemplate.Warning]
}

protocol SizedLabelElement: LabelElement {
    var width: UInt { get }
    var height: UInt { get }
}

protocol ResizableLabelElement: SizedLabelElement {
    var width: UInt { get set }
    var height: UInt { get set }
}

protocol ScaleableLabelElement: LabelElement {
    var scale: UInt { get set }
}

protocol OrientableLabelElement: LabelElement {
    var rotation: Float { get set }
}

// MARK: - Element Coding

enum LabelElementCoder: Codable {
    case text(_: TextElement)
    case barcode(_: BarcodeElement)
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    var labelElement: LabelElement {
        switch self {
        case .text(let element):
            return element
        case .barcode(let element):
            return element
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try TextElement(from: decoder))
        case "barcode":
            self = .barcode(try BarcodeElement(from: decoder))
        default:
            throw LabelFileError.unknownType(type)
        }
    }
    

    func encode(to encoder: Encoder) throws {
        //FIXME: Implement
    }
}
