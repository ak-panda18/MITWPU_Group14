import UIKit

extension UIImageView {
    var contentClippingRect: CGRect {
        guard let image = image, contentMode == .scaleAspectFit else { return bounds }
        
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        
        guard imageWidth > 0 && imageHeight > 0 else { return bounds }
        
        let viewWidth = bounds.width
        let viewHeight = bounds.height
        
        let ratioView = viewWidth / viewHeight
        let ratioImage = imageWidth / imageHeight
        
        var scale: CGFloat
        var drawRect = CGRect.zero
        
        if ratioImage > ratioView {
            scale = viewWidth / imageWidth
            drawRect.size.width = viewWidth
            drawRect.size.height = imageHeight * scale
            drawRect.origin.x = 0
            drawRect.origin.y = (viewHeight - drawRect.size.height) / 2.0
        } else {
            scale = viewHeight / imageHeight
            drawRect.size.width = imageWidth * scale
            drawRect.size.height = viewHeight
            drawRect.origin.x = (viewWidth - drawRect.size.width) / 2.0
            drawRect.origin.y = 0
        }
        
        return drawRect
    }
}
