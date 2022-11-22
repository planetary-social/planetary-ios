//
//  SocialStatsView.swift
//  Planetary
//
//  Created by Martin Dutra on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct SocialStatsView: View {

    var socialStats: ExtendedSocialStats?

    @State
    private var showingFollowers = false

    @State
    private var showingFollows = false

    @State
    private var showingBlocks = false

    @State
    private var showingPubServers = false

    private var isLoading: Bool {
        socialStats == nil
    }

    private var followers: [Identity] {
        socialStats?.followers ?? []
    }

    private var followersAvatars: [ImageMetadata] {
        socialStats?.someFollowersAvatars.map { $0 ?? ImageMetadata(link: .null) } ?? []
    }

    private var follows: [Identity] {
        socialStats?.follows ?? []
    }

    private var followsAvatars: [ImageMetadata] {
        socialStats?.someFollowsAvatars.map { $0 ?? ImageMetadata(link: .null) } ?? []
    }

    private var blocks: [Identity] {
        socialStats?.blocks ?? []
    }

    private var blocksAvatars: [ImageMetadata] {
        socialStats?.someBlocksAvatars.map { $0 ?? ImageMetadata(link: .null) } ?? []
    }

    private var pubServers: [Identity] {
        socialStats?.pubServers ?? []
    }

    private var pubServersAvatars: [ImageMetadata] {
        socialStats?.somePubServersAvatars.map { $0 ?? ImageMetadata(link: .null) } ?? []
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Button {
                showingFollowers = !followers.isEmpty
            } label: {
                tab(
                    label: .followedBy,
                    value: followers.count,
                    avatars: followersAvatars
                )
            }
            .sheet(isPresented: $showingFollowers) {
                identityList(followers, label: .followedByCount, isPresented: $showingFollowers)
            }
            Button {
                showingFollows = !follows.isEmpty
            } label: {
                tab(
                    label: .following,
                    value: follows.count,
                    avatars: followsAvatars
                )
            }
            .sheet(isPresented: $showingFollows) {
                identityList(follows, label: .followingCount, isPresented: $showingFollows)
            }
            Button {
                showingBlocks = !blocks.isEmpty
            } label: {
                tab(
                    label: .blocking,
                    value: blocks.count,
                    avatars: blocksAvatars
                )
            }
            .sheet(isPresented: $showingBlocks) {
                identityList(blocks, label: .blockingCount, isPresented: $showingBlocks)
            }
            Button {
                showingPubServers = !pubServers.isEmpty
            } label: {
                tab(
                    label: .pubServers,
                    value: pubServers.count,
                    avatars: pubServersAvatars
                )
            }
            .sheet(isPresented: $showingPubServers) {
                identityList(pubServers, label: .joinedCount, isPresented: $showingPubServers)
            }
        }
        .padding(EdgeInsets(top: 9, leading: 18, bottom: 18, trailing: 18))
        .redacted(reason: isLoading ? .placeholder : [])
    }

    private func identityList(_ list: [Identity], label: Localized, isPresented: Binding<Bool>) -> some View {
        NavigationView {
            IdentityListView(identities: list)
                .navigationTitle(label.text(["count": "\(list.count)"]))
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresented.wrappedValue = false
                        } label: {
                            Image.navIconDismiss
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tab(label: Localized, value: Int, avatars: [ImageMetadata]) -> some View {
        VStack {
            ZStack(alignment: .leading) {
                ForEach(Array(zip(avatars.indices, avatars)), id: \.0) { index, avatar in
                    AvatarView(metadata: avatar, size: 26)
                        .offset(x: matrix(avatars.count)[index] * 8.0, y: 0)
                }
            }
            .frame(width: avatars.isEmpty ? 0 :  CGFloat(30 + 16 * (avatars.count - 1)), height: 30)
            .background(
                Color.hashtagBg.cornerRadius(99)
            )
            Text("\(value)")
                .font(.title)
                .foregroundLinearGradient(.horizontalAccent)
            Text(label.text.lowercased())
                .font(.caption)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundColor(.secondaryTxt)
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
    static var sample: ExtendedSocialStats {
        ExtendedSocialStats(
            followers: [.null, .null],
            someFollowersAvatars: [nil, nil],
            follows: [.null, .null],
            someFollowsAvatars: [nil, nil],
            blocks: [],
            someBlocksAvatars: [],
            pubServers: [.null],
            somePubServersAvatars: [nil]
        )
    }
    static var previews: some View {
        Group {
            VStack {
                SocialStatsView(socialStats: nil)
                SocialStatsView(socialStats: sample)
            }
            VStack {
                SocialStatsView(socialStats: nil)
                SocialStatsView(socialStats: sample)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
    }
}
