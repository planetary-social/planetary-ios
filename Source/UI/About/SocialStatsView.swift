//
//  SocialStatsView.swift
//  Planetary
//
//  Created by Martin Dutra on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct SocialStatsView: View {

    var socialStats: ExtendedSocialStats

    var onTraitTapHandler: ((SocialStatsView.Trait) -> Void)?

    enum Trait {
        case followers
        case follows
        case ignores
        case pubs
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            tab(
                label: .followedBy,
                value: socialStats.numberOfFollowers,
                avatars: socialStats.followers.map { $0 ?? ImageMetadata(link: .null) }
            ).onTapGesture {
                onTraitTapHandler?(.followers)
            }
            tab(
                label: .following,
                value: socialStats.numberOfFollows,
                avatars: socialStats.follows.map { $0 ?? ImageMetadata(link: .null) }
            )
            tab(
                label: .blocking,
                value: socialStats.numberOfBlocks,
                avatars: socialStats.blocks.map { $0 ?? ImageMetadata(link: .null) }
            )
            tab(
                label: .pubServers,
                value: socialStats.numberOfPubServers,
                avatars: socialStats.pubServers.map { $0 ?? ImageMetadata(link: .null) }
            )
        }
        .padding(EdgeInsets(top: 9, leading: 18, bottom: 18, trailing: 18))
    }

    private func tab(label: Localized, value: Int, avatars: [ImageMetadata]) -> some View {
        VStack {
            ZStack(alignment: .leading) {
                ForEach(Array(zip(avatars.indices, avatars)), id: \.0) { index, avatar in
                    ImageMetadataView(metadata: avatar)
                        .cornerRadius(99)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .offset(x: matrix(avatars.count)[index] * 8.0, y: 0)
                }
            }
            .frame(width: avatars.isEmpty ? 0 :  CGFloat(30 + 16 * (avatars.count - 1)), height: 30)
            .background(
                Color("hashtag-bg").cornerRadius(99)
            )
            SwiftUI.Text("\(value)")
                .font(.system(size: 25))
                .foregroundLinearGradient(
                    LinearGradient(
                        colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            SwiftUI.Text(label.text.lowercased())
                .font(.system(size: 11))
                .foregroundColor(Color("secondary-txt"))
        }
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

struct SocialStatsView_Previews: PreviewProvider {
    static var previews: some View {
        SocialStatsView(socialStats: .zero)
            .redacted(reason: .placeholder)
            .previewLayout(.sizeThatFits)

        let socialStats = ExtendedSocialStats(
            numberOfFollowers: 2,
            followers: [ImageMetadata(link: .null), ImageMetadata(link: .null)],
            numberOfFollows: 1,
            follows: [ImageMetadata(link: .null)],
            numberOfBlocks: 3,
            blocks: [ImageMetadata(link: .null), ImageMetadata(link: .null), ImageMetadata(link: .null)],
            numberOfPubServers: 0,
            pubServers: []
        )
        SocialStatsView(socialStats: socialStats)
            .previewLayout(.sizeThatFits)

        SocialStatsView(socialStats: socialStats)
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
