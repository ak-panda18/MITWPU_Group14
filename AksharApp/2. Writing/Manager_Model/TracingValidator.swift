import UIKit

struct TraceValidator {
    
    static let alphaThreshold: UInt8 = 12

    // MARK: - Image Processing
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
    static func isPointValid(point: CGPoint,
                             inImageView view: UIImageView,
                             maskData: [UInt8],
                             maskSize: CGSize) -> Bool {
        
        let viewSize = view.bounds.size
        let scale = min(viewSize.width / maskSize.width, viewSize.height / maskSize.height)
        let imageDrawSize = CGSize(width: maskSize.width * scale, height: maskSize.height * scale)
        let xOffset = (viewSize.width - imageDrawSize.width) / 2
        let yOffset = (viewSize.height - imageDrawSize.height) / 2
        
        let px = (point.x - xOffset) / scale
        let py = (point.y - yOffset) / scale
        
        guard px >= 0, py >= 0, px < maskSize.width, py < maskSize.height else { return false }
        
        let width = Int(maskSize.width)
        let x = Int(px)
        let y = Int(py)
        
        let pixelIndex = (y * width + x) * 4
        if pixelIndex + 3 >= maskData.count { return false }
        
        return maskData[pixelIndex + 3] > alphaThreshold
    }
    
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
