import Foundation
import CoreGraphics

/// Generate a PDF from a list of CGImages
/// - Parameter images: A list of `CGImage`s, one per PDF page
/// - Parameter dotsPerInch: The resolution of the PDF page in dots per inch
/// - Returns: A `Result` that resolves to either a `Data` object containing the contents of the rendered PDF file, or a `PDFRenderError`
func renderToPDF(images: [CGImage], dotsPerInch: UInt) -> Result<Data, PDFRenderError> {
    let mutablePDFData = NSMutableData()
    guard let pdfDataConsumer = CGDataConsumer(data: mutablePDFData) else {
        return .failure(.failedToInitializeDataStorage)
    }
    
    guard
        let pageWidthInDots = images.map({ $0.width }).map({ dotsToPoints(value: $0, dotsPerInch: dotsPerInch) }).max(),
        let pageHeightInDots = images.map({ $0.height }).map({ dotsToPoints(value: $0, dotsPerInch: dotsPerInch) }).max()
    else {
        return .failure(.noImages)
    }
    
    var mediaBox = CGRect(x: 0, y: 0, width: pageWidthInDots, height: pageHeightInDots)
    guard let context = CGContext(consumer: pdfDataConsumer, mediaBox: &mediaBox, [kCGPDFContextCreator: "LabelTool"] as CFDictionary) else {
        return .failure(.failedToCreatePDFContext)
    }
    context.setAllowsAntialiasing(false)
    context.interpolationQuality = .none
    
    for image in images {
        context.beginPDFPage(nil)
        context.draw(image, in: CGRect(x: 0, y: 0, width: dotsToPoints(value: image.width, dotsPerInch: dotsPerInch), height: dotsToPoints(value: image.height, dotsPerInch: dotsPerInch)))
        context.endPDFPage()
    }
    
    context.closePDF()
    
    return .success(mutablePDFData as Data)
}

private let POINTS_PER_INCH: UInt = 72
private func dotsToPoints(value: Int, dotsPerInch: UInt) -> Int {
    return (value * Int(POINTS_PER_INCH)) / Int(dotsPerInch)
}

enum PDFRenderError: LocalizedError {
    case noImages
    case failedToInitializeDataStorage
    case failedToCreatePDFContext
}
