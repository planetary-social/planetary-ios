//
//  AvatarView.swift
//  Planetary
//
//  Created by Martin Dutra on 11/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct AvatarView: View {

    var metadata: ImageMetadata?
    var size: CGFloat

    var body: some View {
        ZStack {
            ImageMetadataView(metadata: metadata)
                .scaledToFill()
        }.frame(width: size, height: size).cornerRadius(99)
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AvatarView(size: 92)
        }
        .previewLayout(.sizeThatFits)
    }
}

