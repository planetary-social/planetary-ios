//
//  SnowView.swift
//  Planetary
//
//  Created by Christoph on 12/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class SnowView: UIView {

    private let cell: CAEmitterCell = {
        let cell = CAEmitterCell()
        cell.birthRate = 10
        cell.contents = UIImage(named: "icon-planetary-small.png")?.cgImage
        cell.emissionLongitude = CGFloat.pi
        cell.emissionRange = CGFloat.pi / 4
        cell.lifetime = 8.0
        cell.lifetimeRange = 0
        cell.name = "snow"
        cell.scale = 0.3
        cell.scaleRange = 0.1
        cell.scaleSpeed = -0.05
        cell.spin = 2
        cell.spinRange = 3
        cell.velocity = 200
        cell.velocityRange = 200
        return cell
    }()

    private let cellLayer: CAEmitterLayer = {
        let layer = CAEmitterLayer()
        layer.emitterPosition = .zero
        layer.emitterShape = .line
        layer.emitterSize = CGSize(width: 200, height: 1)
        return layer
    }()

    convenience init() {
        self.init(frame: .zero)
        self.backgroundColor = .clear
        self.clipsToBounds = true
        self.isUserInteractionEnabled = false
        self.cellLayer.emitterCells = [self.cell]
        self.layer.addSublayer(self.cellLayer)
    }

    deinit {
        // put a BP here to ensure the view is being released
        // note that this will not be called immediately because
        // the timers will have to finish running before the view
        // can be released, but this should not be more than a few
    }

    override func didMoveToSuperview() {
        self.birthRateTimer(layer: self.cellLayer, cell: self.cell)
        self.windTimer(layer: self.cellLayer, cell: self.cell)
    }

    private func windTimer(layer: CAEmitterLayer,
                           cell: CAEmitterCell) {
        guard self.superview != nil else { return }
        Timer.scheduledTimer(withTimeInterval: 5,
                             repeats: false) {
            _ in
            let duration = TimeInterval(arc4random() % 10)
            let animation = CABasicAnimation(keyPath: "emitterCells.snow.xAcceleration")
            animation.fromValue = cell.xAcceleration
            animation.toValue = CGFloat(arc4random() % 5) * 50
            animation.duration = duration
            animation.isAdditive = true
            layer.add(animation, forKey: "snow.xAcceleration")
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.windTimer(layer: layer, cell: cell)
            }
        }
    }

    private func birthRateTimer(layer: CAEmitterLayer,
                                cell: CAEmitterCell) {
        guard self.superview != nil else { return }
        Timer.scheduledTimer(withTimeInterval: 5,
                             repeats: false) {
            _ in
            let duration = TimeInterval(arc4random() % 10)
            let animation = CABasicAnimation(keyPath: "emitterCells.snow.birthRate")
            animation.fromValue = cell.birthRate
            animation.toValue = CGFloat(arc4random() % 5) * 5
            animation.duration = duration
            animation.isAdditive = true
            layer.add(animation, forKey: "snow.birthRate")
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.birthRateTimer(layer: layer, cell: cell)
            }
        }
    }
}
