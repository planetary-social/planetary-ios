//
//  IdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 23/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

enum IdentityViewBuilder {
    static func build(
        identity: Identity,
        botRepository: BotRepository = BotRepository.shared,
        appController: AppController = AppController.shared
    ) -> some View {
        IdentityView(
            identity: identity,
            dataSource: FeedStrategyMessageDataSource(
                strategy: ProfileStrategy(identity: identity),
                bot: botRepository.current
            )
        ).environmentObject(botRepository).environmentObject(appController)
    }
}

struct IdentityView: View {

    var identity: Identity

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    init(identity: Identity, dataSource: FeedStrategyMessageDataSource) {
        self.identity = identity
        self.dataSource = dataSource
    }

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    @State
    private var about: About?
    
    @State
    private var aliases: [RoomAlias]?

    @State
    private var relationship: Relationship?

    @State
    private var socialStats: ExtendedSocialStats?

    @State
    private var hashtags: [Hashtag]?

    @State
    private var errorMessage: String?

    @State
    private var extendedHeader = true

    @State
    private var headerOffset = CGFloat.zero

    @State
    private var contentOffset = CGFloat.zero

    @State
    private var maxSize = CGSize.zero

    @State
    private var minSize = CGSize.zero

    private var showAlert: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { _ in
            errorMessage = nil
            appController.dismiss(animated: true)
        }
    }

    private func header(extendedHeader: Bool) -> some View {
        IdentityHeaderView(
            identity: identity,
            aliases: aliases,
            about: about,
            relationship: relationship,
            hashtags: hashtags,
            socialStats: socialStats,
            extendedHeader: extendedHeader
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .named("scroll")).minY
                    Color.clear.preference(
                        key: ScrollViewOffsetPreferenceKey.self,
                        value: offset
                    )
                    .frame(height: 0)
                    .border(Color.red)
                }.frame(height: 0)
                header(extendedHeader: extendedHeader)
                    .background {
                        header(extendedHeader: true)
                            .fixedSize(horizontal: false, vertical: true)
                            .hidden()
                            .background {
                                GeometryReader { geometryProxy in
                                    Color.clear.preference(
                                        key: ExtendedSizePreferenceKey.self,
                                        value: geometryProxy.size
                                    )
                                }
                            }
                            .onPreferenceChange(ExtendedSizePreferenceKey.self) { newSize in
                                maxSize = newSize
                            }
                    }
                    .background {
                        header(extendedHeader: false)
                            .hidden()
                            .background {
                                GeometryReader { geometryProxy in
                                    Color.clear.preference(
                                        key: CollapsedSizePreferenceKey.self,
                                        value: geometryProxy.size
                                    )
                                }
                            }
                            .onPreferenceChange(CollapsedSizePreferenceKey.self) { newSize in
                                minSize = newSize
                            }
                    }
                    .zIndex(extendedHeader ? 500 : 1000)
                    .offset(y: headerOffset)
                MessageStack(dataSource: dataSource)
                    .placeholder(when: dataSource.isEmpty) {
                        EmptyPostsView(description: Localized.Message.noPostsDescription)
                    }
                    .background(Color.appBg)
                    .zIndex(extendedHeader ? 1000 : 500)
                    .offset(y: contentOffset)
                Spacer()
                    .frame(height: contentOffset)
            }
        }
        .background(Color.appBg)
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            guard minSize.height > 0, maxSize.height > 0 else {
                return
            }
            let offset = value
            if maxSize.height + offset > minSize.height {
                if !extendedHeader {
                    extendedHeader = true
                    contentOffset = 0
                }
                headerOffset = -offset
            } else {
                if extendedHeader {
                    extendedHeader = false
                    contentOffset = maxSize.height - minSize.height
                }
                headerOffset = -offset
            }
        }
        .navigationTitle(Localized.profile.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                IdentityShareButton(identity: identity)
                IdentityOptionsButton(identity: identity, name: about?.name)
            }
        }
        .alert(isPresented: showAlert) {
            Alert(title: Localized.error.view, message: Text(errorMessage ?? ""))
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateAbout)) { output in
            guard let notifiedAbout = output.about, notifiedAbout.identity == identity else {
                return
            }
            about = notifiedAbout
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { output in
            guard let notifiedRelationship = output.relationship, notifiedRelationship.other == identity else {
                return
            }
            relationship = notifiedRelationship
        }
        .onReceive(NotificationCenter.default.publisher(for: .didBlockUser)) { output in
            guard let notifiedIdentity = output.object as? Identity, notifiedIdentity == identity else {
                return
            }
            let relationshipToUpdate = relationship
            relationshipToUpdate?.isBlocking = true
            relationship = relationshipToUpdate
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUnblockUser)) { output in
            guard let notifiedIdentity = output.object as? Identity, notifiedIdentity == identity else {
                return
            }
            let relationshipToUpdate = relationship
            relationshipToUpdate?.isBlocking = false
            relationship = relationshipToUpdate
        }
        .task {
            loadAbout()
            loadAliases()
            loadRelationship()
            loadHashtags()
            loadSocialStats()
        }
    }

    private func loadAbout() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.about(identity: identityToLoad)
                await MainActor.run {
                    about = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    private func loadAliases() {
        Task.detached {
            let bot = await botRepository.current
            do {
                let result = try await bot.registeredAliases(await identity)
                await MainActor.run {
                    aliases = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    private func loadSocialStats() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let followers: [Identity] = try await bot.followers(identity: identityToLoad).reversed()
                let someFollowers = try await bot.abouts(identities: Array(followers.prefix(2)))
                let followings: [Identity] = try await bot.followings(identity: identityToLoad).reversed()
                let someFollowings = try await bot.abouts(identities: Array(followings.prefix(2)))
                let blocks: [Identity] = try await bot.blocks(identity: identityToLoad).reversed()
                let someBlocks = try await bot.abouts(identities: Array(blocks.prefix(2)))
                let pubs: [Identity] = try await bot.pubs(joinedBy: identityToLoad).map { $0.address.key }.reversed()
                let somePubs = try await bot.abouts(identities: Array(pubs.prefix(2)))
                let result = ExtendedSocialStats(
                    followers: followers,
                    someFollowersAvatars: someFollowers.map { $0?.image },
                    follows: followings,
                    someFollowsAvatars: someFollowings.map { $0?.image },
                    blocks: blocks,
                    someBlocksAvatars: someBlocks.map { $0?.image },
                    pubServers: pubs,
                    somePubServersAvatars: somePubs.map { $0?.image }
                )
                await MainActor.run {
                    socialStats = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    socialStats = .zero
                }
            }
        }
    }

    private func loadHashtags() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.hashtags(usedBy: identityToLoad, limit: 3)
                await MainActor.run {
                    hashtags = result
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    hashtags = []
                }
            }
        }
    }

    private func loadRelationship() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            if let currentIdentity = bot.identity {
                do {
                    let result = try await bot.relationship(from: currentIdentity, to: identityToLoad)
                    await MainActor.run {
                        relationship = result
                    }
                } catch {
                    CrashReporting.shared.reportIfNeeded(error: error)
                    Log.shared.optional(error)
                }
            }
        }
    }
}

fileprivate struct ExtendedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

fileprivate struct CollapsedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

fileprivate struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }

    typealias Value = CGFloat
}

struct IdentityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                IdentityView(
                    identity: .null,
                    dataSource: FeedStrategyMessageDataSource(strategy: StaticAlgorithm(messages: []), bot: FakeBot.shared)
                )
            }
            .preferredColorScheme(.light)

            NavigationView {
                IdentityView(
                    identity: .null,
                    dataSource: FeedStrategyMessageDataSource(strategy: StaticAlgorithm(messages: []), bot: FakeBot.shared)
                )
            }
            .preferredColorScheme(.dark)
        }
        .environmentObject(BotRepository.fake)
        .environmentObject(AppController.shared)
    }
}
