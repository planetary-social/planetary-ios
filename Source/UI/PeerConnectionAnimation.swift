//
//  PeerConnectionAnimation.swift
//  Planetary
//
//  Created by Zef Houssney on 11/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class PeerConnectionAnimation: UIView {

    /// A multiplier applied to the size of all elements.
    var multiplier:      CGFloat

    lazy var lineWidth:       CGFloat = { 1 * self.multiplier }()

    lazy var centerDotSize:   CGFloat = { 7 * self.multiplier }()
    lazy var dotSize:         CGFloat = { 5 * self.multiplier }()

    lazy var insideDiameter:  CGFloat = { 23 * self.multiplier }()
    lazy var outsideDiameter: CGFloat = { 38 * self.multiplier }()

    let insideMax = 11
    let outsideMax = 18

    let dotAnimationDuration: TimeInterval = 0.4

    let insideAnimationSpeed: TimeInterval = 5.7
    let outsideAnimationSpeed: TimeInterval = 4.1

    var totalDiameter: CGFloat {
        return outsideDiameter + (dotSize / 2)
    }
    var totalRadius: CGFloat {
        return totalDiameter / 2
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(square: totalDiameter)
    }

    private var insideDots = 0 {
        didSet {
            self.insideDots = min(max(self.insideDots, 0), self.insideMax)
        }
    }

    private var outsideDots = 0 {
        didSet {
            self.outsideDots = min(max(self.outsideDots, 0), self.outsideMax)
        }
    }

    private var centerDot: CALayer!
    private var insideCircle: CAShapeLayer!
    private var outsideCircle: CAShapeLayer!
    private var insideReplicator: CAReplicatorLayer!
    private var outsideReplicator: CAReplicatorLayer!

    var inColor = UIColor.tint.default
    var outColor = UIColor.tint.default.withAlphaComponent(0.6)
    var disabledColor = #colorLiteral(red: 0.6195520163, green: 0.619643569, blue: 0.6195320487, alpha: 1)
    var searchColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)

    init(color: UIColor,
         sizeMultiplier: CGFloat = 1.0,
         lineWidth: CGFloat = 1,
         centerDotSize: CGFloat = 7,
         dotSize: CGFloat = 5,
         insideDiameter: CGFloat = 23,
         outsideDiameter: CGFloat = 38
    ) {
        self.multiplier = sizeMultiplier

        super.init(frame: .zero)
        
        self.inColor = color
        self.outColor = color
        self.disabledColor = color
        self.searchColor = color
        
        self.multiplier = sizeMultiplier
        self.lineWidth = lineWidth
        self.centerDotSize = centerDotSize
        self.dotSize = dotSize
        self.insideDiameter = insideDiameter
        self.outsideDiameter = outsideDiameter

        self.insideCircle = addCircle(size: self.insideDiameter)
        self.outsideCircle = addCircle(size: self.outsideDiameter)

        self.insideReplicator = addDots(color: self.inColor,
                                        size: self.insideDiameter,
                                        rotationSpeed: self.insideAnimationSpeed)

        self.outsideReplicator = addDots(color: self.outColor,
                                         size: self.outsideDiameter,
                                         rotationSpeed: self.outsideAnimationSpeed)

        self.addCenterDot()

        self.setDotCount(inside: true, count: 0, animated: false)
        self.setDotCount(inside: false, count: 0, animated: false)
    }

    private func addCenterDot() {
        let circle = CALayer()

        let position = self.totalRadius - (self.centerDotSize / 2)
        circle.frame = CGRect(x: position, y: position, width: self.centerDotSize, height: self.centerDotSize)
        circle.cornerRadius = self.centerDotSize / 2
        circle.backgroundColor = self.inColor.cgColor

        self.layer.addSublayer(circle)
    }

    private func addCircle(size: CGFloat) -> CAShapeLayer {
        let radius = size / 2
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: size, y: size),
                                      radius: radius,
                                      startAngle: CGFloat(0),
                                      endAngle: CGFloat.pi * 2,
                                      clockwise: true)

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = circlePath.cgPath

        let center = self.totalRadius - size
        shapeLayer.position = CGPoint(x: center, y: center)

        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = self.disabledColor.cgColor

        shapeLayer.lineWidth = self.lineWidth

        self.layer.addSublayer(shapeLayer)

        return shapeLayer
    }

    private func addDots(color: UIColor, size: CGFloat, rotationSpeed: TimeInterval) -> CAReplicatorLayer {
        let replicatorLayer = CAReplicatorLayer()
        replicatorLayer.position = CGPoint(x: self.totalRadius, y: self.totalRadius)
        replicatorLayer.bounds = CGRect(x: 0, y: 0, width: size, height: size)


        let circle = CALayer()
        circle.frame = CGRect(x: 0, y: 0, width: self.dotSize, height: self.dotSize)
        circle.cornerRadius = self.dotSize / 2
        circle.backgroundColor = color.cgColor
        circle.position = CGPoint(x: 0, y: size / 2)

        replicatorLayer.addSublayer(circle)

        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = rotationSpeed
        rotation.isRemovedOnCompletion = false
        rotation.repeatCount = .greatestFiniteMagnitude
        replicatorLayer.add(rotation, forKey: "rotation")

        self.layer.addSublayer(replicatorLayer)

        return replicatorLayer
    }

    private func setDots(replicator: CAReplicatorLayer, circle: CAShapeLayer, dotCount: Int, duration: TimeInterval, completion: (() -> Void)? = nil) {

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)

        if dotCount > 0 {
            circle.strokeColor = (circle == self.insideCircle ? self.inColor : self.outColor).cgColor
            replicator.opacity = 1

            let angle = CGFloat.pi * 2 / CGFloat(dotCount)
            replicator.instanceTransform = CATransform3DMakeRotation(angle, 0, 0, 1)

            replicator.instanceCount = dotCount
        } else {
            replicator.opacity = 0
            circle.strokeColor = self.disabledColor.cgColor
        }

        CATransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion?()
        }
    }

    func setDotCount(inside: Bool, count: Int, animated: Bool, completion: (() -> Void)? = nil) {
        let duration = animated ? self.dotAnimationDuration : 0

        if inside {
            self.insideDots = count
            self.setDots(replicator: insideReplicator, circle: insideCircle, dotCount: self.insideDots, duration: duration, completion: completion)
        } else {
            self.outsideDots = count
            self.setDots(replicator: outsideReplicator, circle: outsideCircle, dotCount: self.outsideDots, duration: duration, completion: completion)
        }
    }
    
    func searchAnimation(completion: (() -> Void)? = nil) {
        insideCircle.strokeColor = self.searchColor.cgColor
        outsideCircle.strokeColor = self.searchColor.cgColor
    }
    

    required init?(coder: NSCoder) {
        fatalError("Not implemented.")
    }
}
