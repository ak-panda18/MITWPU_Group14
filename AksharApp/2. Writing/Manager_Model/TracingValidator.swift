import UIKit

struct TraceValidator {
    
    // Config
    static let alphaThreshold: UInt8 = 12

    // MARK: - Image Processing
    /// Converts an image into a raw byte array for pixel analysis
    static func getNormalizedRGBAData(from image: UIImage) -> ([UInt8], CGSize)? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = 4 * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(data: &rawData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (rawData, CGSize(width: width, height: height))
    }
    
    // MARK: - Point Validation
    /// Checks if a touch point falls on a valid "ink" part of the mask
    static func isPointValid(point: CGPoint,
                             inImageView view: UIImageView,
                             maskData: [UInt8],
                             maskSize: CGSize) -> Bool {
        
        // 1. Calculate Scale & Offset to map View coordinates to Image coordinates
        let viewSize = view.bounds.size
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2
        
        // 2. Map point
        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        // 3. Bounds Check
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else { return false }
        
        // 4. Pixel Check
        let width = Int(maskSize.width)
        let x = Int(px)
        let y = Int(py)
        
        let pixelIndex = (y * width + x) * 4
        if pixelIndex + 3 >= maskData.count { return false }
        
        // Check Alpha channel
        return maskData[pixelIndex + 3] > alphaThreshold
    }
    
    /// Returns the pixel indices that the brush touched (for coverage calculation)
    static func getTouchedPixels(point: CGPoint,
                                 inImageView view: UIImageView,
                                 maskSize: CGSize,
                                 brushWidth: CGFloat) -> [Int] {
        
        let viewSize = view.bounds.size
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2
        
        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        let w = Int(maskSize.width)
        let h = Int(maskSize.height)
        let centerX = Int(px)
        let centerY = Int(py)
        let brushRadius = Int(brushWidth / scale)
        
        var touchedIndices: [Int] = []
        
        for dy in -brushRadius...brushRadius {
            for dx in -brushRadius...brushRadius {
                let x = centerX + dx
                let y = centerY + dy
                if x < 0 || y < 0 || x >= w || y >= h { continue }
                if dx*dx + dy*dy > brushRadius*brushRadius { continue } // Circular brush
                
                let idx = y * w + x
                touchedIndices.append(idx)
            }
        }
        return touchedIndices
    }
}
