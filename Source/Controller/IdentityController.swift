//
//  IdentityController.swift
//  Planetary
//
//  Created by Martin Dutra on 30/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import Logger
import CrashReporting
import Support

/// A coordinator for `IdentityView`
@MainActor class IdentityController: IdentityViewModel {

    @Published var identity: Identity

    private var bot: Bot

    @Published var about: About?

    @Published var socialStats: ExtendedSocialStats?

    @Published var hashtags: [Hashtag]?

    @Published var relationship: Relationship?

    @Published var errorMessage: String?

    init(identity: Identity, bot: Bot) {
        self.identity = identity
        self.bot = bot
        loadAbout()
    }

    func followButtonTapped() {
        guard let relationship = relationship else {
            return
        }
        Task.detached { [bot, identity, weak self] in
            Analytics.shared.trackDidTapButton(buttonName: "follow")
            do {
                if relationship.isBlocking {
                    try await bot.block(identity: identity)
                    Analytics.shared.trackDidBlockIdentity()
                    relationship.isBlocking = false
                } else {
                    if relationship.isFollowing {
                        try await bot.unfollow(identity: identity)
                        Analytics.shared.trackDidUnfollowIdentity()
                        relationship.isFollowing = false
                    } else {
                        try await bot.follow(identity: identity)
                        Analytics.shared.trackDidFollowIdentity()
                        relationship.isFollowing = true
                    }
                }
                await self?.updateRelationship(relationship)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await self?.updateErrorMessage(error.localizedDescription)
            }
        }
    }
    
    func hashtagTapped(_ hashtag: Hashtag) {
        AppController.shared.open(string: hashtag.string)
    }

    func didDismiss() {
        AppController.shared.dismiss(animated: true)
    }

    func didDismissError() {
        errorMessage = nil
        didDismiss()
    }

    private func updateAbout(_ about: About?) {
        self.about = about
    }

    private func updateSocialStats(_ socialStats: ExtendedSocialStats) {
        self.socialStats = socialStats
    }

    private func updateHashtags(_ hashtags: [Hashtag]) {
        self.hashtags = hashtags
    }

    private func updateRelationship(_ relationship: Relationship) {
        self.relationship = relationship
    }

    private func updateErrorMessage(_ errorMessage: String) {
        self.errorMessage = errorMessage
    }

    private func loadAbout() {
        Task.detached { [bot, identity, weak self] in
            do {
                let about = try await bot.about(identity: identity)
                await self?.updateAbout(about)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await self?.updateErrorMessage(error.localizedDescription)
            }

            if let currentIdentity = Bots.current.identity {
                do {
                    let relationship = try await Bots.current.relationship(from: currentIdentity, to: identity)
                    await self?.updateRelationship(relationship)
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await self?.updateErrorMessage(error.localizedDescription)
                }
            }

            do {
                let followers: [Identity] = try await Bots.current.followers(identity: identity).reversed()
                let someFollowers = try await Bots.current.abouts(identities: Array(followers.prefix(2)))
                let followings: [Identity] = try await Bots.current.followings(identity: identity).reversed()
                let someFollowings = try await Bots.current.abouts(identities: Array(followings.prefix(2)))
                let blocks: [Identity] = try await Bots.current.blocks(identity: identity).reversed()
                let someBlocks = try await Bots.current.abouts(identities: Array(blocks.prefix(2)))
                let pubs: [Identity] = try await Bots.current.pubs(joinedBy: identity).map { $0.address.key }.reversed()
                let somePubs = try await Bots.current.abouts(identities: Array(pubs.prefix(2)))
                await self?.updateSocialStats(ExtendedSocialStats(
                    followers: followers,
                    someFollowersAvatars: someFollowers.map { $0?.image },
                    follows: followings,
                    someFollowsAvatars: someFollowings.map { $0?.image },
                    blocks: blocks,
                    someBlocksAvatars: someBlocks.map { $0?.image },
                    pubServers: pubs,
                    somePubServersAvatars: somePubs.map { $0?.image }
                ))
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await self?.updateErrorMessage(error.localizedDescription)
            }

            var hashtags = [Hashtag]()
            do {
                hashtags = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                await self?.updateHashtags(hashtags)
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await self?.updateErrorMessage(error.localizedDescription)
            }
        }
    }
}
