import Foundation
import Combine

extension LabelTemplate {
    /// A `CGContext` appropriate for rendering the label design in a printable format
    /// - Note: This produces a grayscale bitmap context with disabled anti-aliasing and associated subpixel layout
    var contextForPrinting: CGContext {
        let context = CGContext.init(data: nil, width: Int(self.width), height: Int(self.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace.init(name: CGColorSpace.linearGray)!, bitmapInfo: 0)!
        context.setAllowsFontSmoothing(false)
        context.setAllowsFontSubpixelPositioning(false)
        context.setAllowsFontSubpixelQuantization(false)
        context.setAllowsAntialiasing(false)
        context.interpolationQuality = .none
        return context
    }
    
    /// Render the label design with the given elements
    /// - Parameter context: The `CGContext` into which the label design should be rendered
    /// - Parameter labelData: An optional key-value dictionary of data with which to populate the elements of the label
    /// - Parameter showBoundingBoxes: A boolean flag indicating whether or not the bounding boxes of label elements should be drawn
    /// - Parameter valueRenderer: a function that preprocesses `valuePrototype` in some way before rendering (e.g. to substitute field values)
    /// - Parameter valuePrototype: a `String` that contains the prototype of the field's value, which may be modified in some way before rendering
    /// - Returns: A list of zero or more `LabelElementWarnings` generated during the rendering process
    func render(inContext context: CGContext, valueRenderer: (_ valuePrototype: String) -> String) -> [LabelTemplate.Warning] {
        var warnings: [LabelTemplate.Warning] = []

        context.setFillColor(CGColor.white)
        context.fill(self.bounds)

        for element in self.labelElements {
            context.saveGState()
            warnings.append(contentsOf: element.render(inContext: context, valueRenderer: valueRenderer))
            context.restoreGState()
        }
        
        return warnings
    }

    /// Render the label design to an image
    /// - Parameter valueRenderer: a function that preprocesses `valuePrototype` in some way before rendering (e.g. to substitute field values)
    /// - Parameter valuePrototype: a `String` that contains the prototype of the field's value, which may be modified in some way before rendering
    /// - Returns: A `Result` that resolves to a `RenderedLabel` and completes, or a `LabelTemplate.RenderError`
    func renderToImage(valueRenderer: @escaping (_ valuePrototype: String) -> String) -> Result<RenderedLabel, Self.Error> {
        let context = self.contextForPrinting
        let warnings = self.render(inContext: context, valueRenderer: valueRenderer)
        if let (image, pixelData) = binarize(context.makeImage()!) { // safe to force `makeImage()` because we know that `contextForPrinting` is a bitmap context
            return .success(RenderedLabel(image: image, pixelData: pixelData, warnings: warnings))
        } else {
            return .failure(LabelTemplate.Error.imageBinarizationFailed)
        }
    }

    struct RenderedLabel {
        var image: CGImage
        var pixelData: [UInt8]
        var warnings: [LabelTemplate.Warning]
    }

    // MARK: - Error/Warning Types

    enum Warning {
        case missingField(_ descriptor: LabelFieldDescriptor)
        case textTruncated(fieldIdentifier: String, hiddenCharacters: UInt)
        case invalidValue(value: String, reason: String?)
        
        var name: String {
            switch self {
            case .missingField:
                return "Missing Value"
            case .textTruncated:
                return "Text Truncated"
            case .invalidValue:
                return "Invalid Value"
            }
        }
        
        var description: String {
            switch self {
            case .missingField(let descriptor):
                switch descriptor.type {
                case .computed:
                    return "\"#{\(descriptor.name)}\" is not a known computed field"
                case .userDefined:
                    return "Expected a value for field named \"${\(descriptor.name)}\""
                }
            case .textTruncated(let fieldIdentifier, let hiddenCharacters):
                return "The text in \"\(fieldIdentifier)\" is too large to fit in the given frame (\(hiddenCharacters) character\(hiddenCharacters == 1 ? "" : "s") hidden)"
            case .invalidValue(let value, let reason):
                return "The value \"\(value)\" is invalid" + (reason != nil ? ": \(reason!)" : "" )
            }
        }
    }

    enum Error: LocalizedError {
        case imageBinarizationFailed
        
        var errorDescription: String? {
            switch self {
            case .imageBinarizationFailed:
                return "The label image could not be binarized to black-and-white"
            }
        }
    }
}
