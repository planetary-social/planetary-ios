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
            BlobView(blob: Blob(identifier: metadata?.id ?? .null))
                .scaledToFill()
        }
        .frame(width: size, height: size)
        .cornerRadius(99)
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                AvatarView(size: 25)
                AvatarView(size: 45)
                AvatarView(size: 87)
            }
            VStack {
                AvatarView(size: 25)
                AvatarView(size: 45)
                AvatarView(size: 87)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
