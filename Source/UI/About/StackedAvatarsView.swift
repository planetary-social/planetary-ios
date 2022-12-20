//
//  StackedAvatarsView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays a stacked list of avatars as we use it in when displaying replies in a post, and a list of
/// followers/follows/blocks in a profile.
struct StackedAvatarsView: View {
    /// The list of avatars to display
    var avatars: [ImageMetadata]

    /// The size of the circle avatar (it doesn't counts the border)
    var size: CGFloat = 26

    /// The size of the border. Use zero if you don't want any background
    var border: CGFloat = 2

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(zip(avatars.indices, avatars)), id: \.0) { index, avatar in
                AvatarView(metadata: avatar, size: size)
                    .offset(x: matrix(avatars.count)[index] * totalSize / 4, y: 0)
            }
        }
        .frame(
            width: avatars.isEmpty ? 0 : totalSize + CGFloat(Int(totalSize) / 2 * (avatars.count - 1)),
            height: totalSize
        )
        .background(
            Color.hashtagBg.cornerRadius(99)
        )
    }

    private var totalSize: CGFloat {
        size + border * 2
    }

    private func matrix(_ numberOfItems: Int) -> [CGFloat] {
        var startingArray: [CGFloat] = []
        if numberOfItems.isMultiple(of: 2) {
            startingArray = []
        } else {
            startingArray = [0]
        }
        let arrayToAppend = stride(
            from: 1.0 + CGFloat(startingArray.count),
            through: CGFloat(numberOfItems / 2) + CGFloat(startingArray.count),
            by: 1.0
        )
        startingArray.insert(contentsOf: arrayToAppend.map { $0 * -1 }, at: 0)
        startingArray.append(contentsOf: arrayToAppend)
        return startingArray
    }
}

struct StackedAvatarsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                StackedAvatarsView(avatars: [])
                StackedAvatarsView(avatars: [ImageMetadata(link: .null)])
                StackedAvatarsView(avatars: [ImageMetadata(link: .null), ImageMetadata(link: .null)])
                StackedAvatarsView(avatars: [], size: 20, border: 0)
                StackedAvatarsView(avatars: [ImageMetadata(link: .null)], size: 20, border: 0)
                StackedAvatarsView(
                    avatars: [ImageMetadata(link: .null), ImageMetadata(link: .null)],
                    size: 20,
                    border: 0
                )
            }
            VStack {
                StackedAvatarsView(avatars: [])
                StackedAvatarsView(avatars: [ImageMetadata(link: .null)])
                StackedAvatarsView(avatars: [ImageMetadata(link: .null), ImageMetadata(link: .null)])
                StackedAvatarsView(avatars: [], size: 20, border: 0)
                StackedAvatarsView(avatars: [ImageMetadata(link: .null)], size: 20, border: 0)
                StackedAvatarsView(
                    avatars: [ImageMetadata(link: .null), ImageMetadata(link: .null)],
                    size: 20,
                    border: 0
                )
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
    }
}
