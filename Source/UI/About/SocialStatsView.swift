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

    var identity: Identity

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var socialStats: ExtendedSocialStats = .zero

    @State
    private var showingFollowers = false

    @State
    private var showingFollows = false

    @State
    private var showingBlocks = false

    @State
    private var showingPubServers = false

    @State
    private var isLoading = true

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
                        .navigationBarTitleDisplayMode(.inline)
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
                        .navigationBarTitleDisplayMode(.inline)
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
                        .navigationBarTitleDisplayMode(.inline)
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
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .padding(EdgeInsets(top: 9, leading: 18, bottom: 18, trailing: 18))
        .redacted(reason: isLoading ? .placeholder : [])
        .task {
            Task.detached { [identity] in
                let bot = await botRepository.current
                do {
                    let followers: [Identity] = try await bot.followers(identity: identity).reversed()
                    let someFollowers = try await bot.abouts(identities: Array(followers.prefix(2)))
                    let followings: [Identity] = try await bot.followings(identity: identity).reversed()
                    let someFollowings = try await bot.abouts(identities: Array(followings.prefix(2)))
                    let blocks: [Identity] = try await bot.blocks(identity: identity).reversed()
                    let someBlocks = try await bot.abouts(identities: Array(blocks.prefix(2)))
                    let pubs: [Identity] = try await bot.pubs(joinedBy: identity).map { $0.address.key }.reversed()
                    let somePubs = try await bot.abouts(identities: Array(pubs.prefix(2)))
                    await MainActor.run {
                        socialStats = ExtendedSocialStats(
                            followers: followers,
                            someFollowersAvatars: someFollowers.map { $0?.image },
                            follows: followings,
                            someFollowsAvatars: someFollowings.map { $0?.image },
                            blocks: blocks,
                            someBlocksAvatars: someBlocks.map { $0?.image },
                            pubServers: pubs,
                            somePubServersAvatars: somePubs.map { $0?.image }
                        )
                        isLoading = false
                    }
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
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
    static var previews: some View {
        SocialStatsView(identity: .null)
            .previewLayout(.sizeThatFits)
            .environmentObject(BotRepository.shared)

        SocialStatsView(identity: .null)
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .environmentObject(BotRepository.shared)
    }
}
