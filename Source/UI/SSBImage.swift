//
//  SSBImage.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/25/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct SSBImage: UIViewRepresentable {
    
    var metadata: ImageMetadata?
    
    var animated = false

    func makeUIView(context: Context) -> ImageView {
        let view = ImageView()
        view.set(image: metadata, animated: animated)
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ uiView: ImageView, context: Context) {}
}
