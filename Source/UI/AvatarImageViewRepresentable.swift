//
//  AvatarImageViewRepresentable.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/25/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A SwiftUI wrapper around the UIKit `AvatarImageView`.
struct AvatarImageViewRepresentable: UIViewRepresentable {
    
    var metadata: ImageMetadata?
    
    var animated = false

    func makeUIView(context: Context) -> AvatarImageView {
        let view = AvatarImageView()
        view.set(image: metadata, animated: animated)
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: AvatarImageView, context: Context) {}
}
