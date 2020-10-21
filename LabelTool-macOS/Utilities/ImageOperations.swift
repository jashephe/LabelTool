import Foundation
import CoreImage
import Metal
import MetalKit
import MetalPerformanceShaders

// MARK: Binarization

func binarize(_ image: CGImage, threshold: Float = 0.5) -> (CGImage, [UInt8])? {
    // Initialize Metal devices
    guard
        let device = MTLCreateSystemDefaultDevice(),
        let commandQueue = device.makeCommandQueue(),
        let commandBuffer = commandQueue.makeCommandBuffer()
    else {
            return nil
    }
    
    // Load the input `CGImage` into a `MTLTexture`
    let textureLoader = MTKTextureLoader(device: device)
    guard let inputTexture = try? textureLoader.newTexture(cgImage: image, options: [MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.topLeft, MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue)]) else {
        return nil
    }
    
    // Create an `MTLTexture` to store the output of the image processing
    let outputTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: inputTexture.pixelFormat, width: inputTexture.width, height: inputTexture.height, mipmapped: false)
    outputTextureDescriptor.usage = [.shaderWrite, .shaderRead]
    guard let outputTexture = device.makeTexture(descriptor: outputTextureDescriptor) else {
        return nil
    }
    
    // Apply the threshold kernel
    let threshold = MPSImageThresholdBinary(device: device, thresholdValue: threshold, maximumValue: 1.0, linearGrayColorTransform: nil)
    threshold.encode(commandBuffer: commandBuffer, sourceTexture: inputTexture, destinationTexture: outputTexture)
    
    // Synchronize the result with the output texture
    guard let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder() else {
        return nil
    }
    blitCommandEncoder.synchronize(resource: outputTexture)
    blitCommandEncoder.endEncoding()
    
    // Commit the computations to the GPU, and wait for the output
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    // Generate a `CGImage` from the `MTLTexture` by way of a `CIImage`
    //
    // Note that `.oriented(.downMirrored)` is used to accomodate the differences in origin between CoreGraphics and Metal.
    // If `[MTKTextureLoader.Option.origin: MTKTextureLoader.Origin.bottomLeft]` is used instead when the input texture is loaded,
    // the output texture will correctly be right side up, but the raw texture data used for `rawPixels` below will be upside down.
    // Loading with an origin of `.bottomLeft` and then applying the `.downMirrored` orientation to the output ensures that both the
    // output image and output pixel data buffer are properly oriented. If there's a better solution to this, I don't know it.
    let outputImage = CIImage(mtlTexture: outputTexture, options: [CIImageOption.colorSpace : (image.colorSpace ?? CGColorSpace(name: CGColorSpace.linearGray)!)])?.oriented(.downMirrored).toCGImage()
    
    // Get the array of raw pixel values from the output `MTLTexture`
    var rawPixels = Array<UInt8>(repeating: UInt8(0), count: outputTexture.width * outputTexture.height)
    outputTexture.getBytes(&rawPixels, bytesPerRow: MemoryLayout<UInt8>.size * outputTexture.width, from: MTLRegionMake2D(0, 0, outputTexture.width, outputTexture.height), mipmapLevel: 0)
    
    if let outputImage = outputImage {
        return (outputImage, rawPixels)
    } else {
        return nil
    }
}

// MARK: - Utilities

extension CIImage {
    /// Render this `CIImage` to a `CGImage`
    func toCGImage(format: CIFormat = CIFormat.L8, colorSpace: CGColorSpace = CGColorSpace.init(name: CGColorSpace.linearGray)!) -> CGImage? {
        let context = CIContext()
        return context.createCGImage(self, from: self.extent, format: format, colorSpace: colorSpace, deferred: false)
    }
}
