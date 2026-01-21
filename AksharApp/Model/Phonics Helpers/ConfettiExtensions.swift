//
//  ConfettiExtensions.swift
//  AksharApp
//
//  Created by SDC-USER on 12/01/26.
//

import UIKit
extension UIViewController {
    func triggerConfetti() {
        let emitter = CAEmitterLayer()
        
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        
        let colors: [UIColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPink, .systemPurple, .systemOrange]
        
        let cells: [CAEmitterCell] = colors.map { color in
            let cell = CAEmitterCell()
            cell.birthRate = 12
            cell.lifetime = 4.0
            cell.velocity = CGFloat.random(in: 150...250)
            cell.velocityRange = 50
            cell.emissionRange = .pi
            cell.yAcceleration = 300
            cell.spin = 2.0
            cell.spinRange = 4.0
            cell.scale = 0.8
            cell.scaleRange = 0.3
            cell.contents = createConfettiImage(color: color)?.cgImage
            return cell
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            emitter.birthRate = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            emitter.removeFromSuperlayer()
        }
    }
    
    private func createConfettiImage(color: UIColor) -> UIImage? {
        let size = CGSize(width: 20, height: 10)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
