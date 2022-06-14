//
//  LottieAnimation.swift
//  Planetary
//
//  Created by Matthew Lorentz on 5/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Lottie

/// A view that plays an Adobe After Effects animation.
/// https://designcode.io/swiftui-handbook-lottie-animation
struct LottieAnimation: UIViewRepresentable {
    let name: String
    let loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> LottieView {
        let animationView = AnimationView()
        let animation = Animation.named(name)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.play()

        return animationView
    }

    func updateUIView(_ uiView: LottieView, context: Context) {
    }
}

struct LottieAnimation_Previews: PreviewProvider {
    static var previews: some View {
        LottieAnimation(name: "bouncing_ellipse")
            .previewLayout(.sizeThatFits)
            .background(Color.black)
    }
}
