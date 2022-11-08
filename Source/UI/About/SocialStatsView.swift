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

    @State
    private var showingFollowers = false

    @State
    private var showingFollows = false

    @State
    private var showingBlocks = false

    @State
    private var showingPubServers = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            tab(
                label: .followedBy,
                value: socialStats.followers.count,
                avatars: socialStats.someFollowersAvatars.map { $0 ?? ImageMetadata(link: .null) }
            )
            .onTapGesture {
                showingFollowers = true
            }
            .sheet(isPresented: $showingFollowers) {
                NavigationView {
                    IdentityListView(identities: socialStats.followers)
                        .navigationTitle(Localized.followedByCount.text(["count": "\(socialStats.followers.count)"]))
                }
            }
            tab(
                label: .following,
                value: socialStats.follows.count,
                avatars: socialStats.someFollowsAvatars.map { $0 ?? ImageMetadata(link: .null) }
            )
            .onTapGesture {
                showingFollows = true
            }
            .sheet(isPresented: $showingFollows) {
                NavigationView {
                    IdentityListView(identities: socialStats.follows)
                        .navigationTitle(Localized.followingCount.text(["count": "\(socialStats.follows.count)"]))
                }
            }
            tab(
                label: .blocking,
                value: socialStats.blocks.count,
                avatars: socialStats.someBlocksAvatars.map { $0 ?? ImageMetadata(link: .null) }
            )
            .onTapGesture {
                showingBlocks = true
            }
            .sheet(isPresented: $showingBlocks) {
                NavigationView {
                    IdentityListView(identities: socialStats.blocks)
                        .navigationTitle(Localized.blockingCount.text(["count": "\(socialStats.blocks.count)"]))
                }
            }
            tab(
                label: .pubServers,
                value: socialStats.pubServers.count,
                avatars: socialStats.somePubServersAvatars.map { $0 ?? ImageMetadata(link: .null) }
            )
            .onTapGesture {
                showingPubServers = true
            }
            .sheet(isPresented: $showingPubServers) {
                NavigationView {
                    IdentityListView(identities: socialStats.pubServers)
                        .navigationTitle(Localized.joinedCount.text(["count": "\(socialStats.pubServers.count)"]))
                }
            }
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
            followers: [.null, .null],
            someFollowersAvatars: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3")],
            follows: [.null],
            someFollowsAvatars: [ImageMetadata(link: "&avatar4")],
            blocks: [.null, .null, .null],
            someBlocksAvatars: [ImageMetadata(link: "&avatar1"), ImageMetadata(link: "&avatar3"), ImageMetadata(link: "&avatar4")],
            pubServers: [],
            somePubServersAvatars: []
        )
        SocialStatsView(socialStats: socialStats)
            .previewLayout(.sizeThatFits)

        SocialStatsView(socialStats: socialStats)
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
