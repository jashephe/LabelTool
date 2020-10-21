import Foundation
import ZXingObjC
import ExceptionCatcher

struct BarcodeElement: ScaleableLabelElement & OrientableLabelElement {
    var x: Int
    var y: Int
    var scale: UInt
    var rotation: Float {
        get {
            return self._rotation ?? 0
        }
        set(newRotation) {
            self._rotation = newRotation
        }
    }
    private var _rotation: Float?
    var valuePrototype: String

    // MARK: Coding

    enum CodingKeys: String, CodingKey {
        case x
        case y
        case scale
        case _rotation = "rotation"
        case valuePrototype = "value"
    }

    //MARK: Implementation

    func render(inContext context: CGContext, valueRenderer: (String) -> String) -> [LabelTemplate.Warning] {
        let adjustedValue = valueRenderer(self.valuePrototype)

        let barcodeWriter = ZXDataMatrixWriter()
        let hints = ZXEncodeHints()
        hints.dataMatrixShape = ZXDataMatrixSymbolShapeHintForceRectangle
        hints.encoding = String.Encoding.utf8.rawValue
        hints.margin = NSNumber(integerLiteral: 0)

        let barcodeMatrix: ZXBitMatrix
        do {
            let maybeBarcodeMatrix = try ExceptionCatcher.catch {
                 return try? barcodeWriter.encode(adjustedValue, format: kBarcodeFormatDataMatrix, width: 36, height: 12, hints: hints)
            }
            guard let theBarcodeMatrix = maybeBarcodeMatrix else {
                return [.invalidValue(value: adjustedValue, reason: "could not encode to DataMatrix barcode")]
            }
            barcodeMatrix = theBarcodeMatrix
        } catch let error {
            return [.invalidValue(value: adjustedValue, reason: "could not encode to DataMatrix barcode (\"\(error.localizedDescription)\")")]
        }

        context.translateBy(x: CGFloat(self.x), y: CGFloat(self.y))
        context.rotate(by: CGFloat(degreesToRadians(self.rotation)))

        context.setFillColor(CGColor.black)
        for i in 0..<barcodeMatrix.height {
            for j in 0..<barcodeMatrix.width {
                if barcodeMatrix.getX(j, y: i) {
                    context.fill(CGRect(x: CGFloat(j) * CGFloat(scale), y: CGFloat(barcodeMatrix.height - i) * CGFloat(scale), width: CGFloat(scale), height: CGFloat(self.scale)))
                }
            }
        }

        return []
    }
}
