//
//  PeerConnectionAnimationView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/22/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// An animated graphic that shows the user how many peers are connected with a solar system metaphor.
struct PeerConnectionAnimationView: UIViewRepresentable {
    
    /// The number of peers that are connected. Will correspond to the number of dots in the graphic.
    var peerCount: Int
    
    let sizeMultiplier:  CGFloat = 1
    let lineWidth:       CGFloat = 1.7
    let centerDotSize:   CGFloat = 5
    let dotSize:         CGFloat = 5
    let insideDiameter:  CGFloat = 16
    let outsideDiameter: CGFloat = 29

    func makeUIView(context: Context) -> PeerConnectionAnimation {
        let animationView = PeerConnectionAnimation(
            color: UIColor(named: "defaultTint")!,
            sizeMultiplier: sizeMultiplier,
            lineWidth: lineWidth,
            centerDotSize: centerDotSize,
            dotSize: dotSize,
            insideDiameter: insideDiameter,
            outsideDiameter: outsideDiameter
        )
        animationView.searchAnimation()
        return animationView
    }

    func updateUIView(_ uiView: PeerConnectionAnimation, context: Context) {
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let innerDotCount = peerCount / 2
        let outerDotCount = peerCount - innerDotCount
        uiView.setDotCount(inside: true, count: innerDotCount, animated: true)
        uiView.setDotCount(inside: false, count: outerDotCount, animated: true)
    }
}

struct PeerConnectionAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            VStack(spacing: 16) {
                PeerConnectionAnimationView(peerCount: 0)
                PeerConnectionAnimationView(peerCount: 1)
                PeerConnectionAnimationView(peerCount: 2)
                PeerConnectionAnimationView(peerCount: 3)
                PeerConnectionAnimationView(peerCount: 5)
                PeerConnectionAnimationView(peerCount: 9)
                PeerConnectionAnimationView(peerCount: 99)
            }
            .padding(16)
        }
        .background(Color("appBackground"))
        .previewLayout(.sizeThatFits)
    }
}
