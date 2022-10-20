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

    func block() {
        Analytics.shared.trackDidSelectAction(actionName: "block_identity")
        AppController.shared.promptToBlock(identity, name: about?.name)
    }

    func report() {
        guard let currentIdentity = bot.identity else {
            return
        }
        Analytics.shared.trackDidSelectAction(actionName: "report_user")
        let profile = AbusiveProfile(identifier: identity, name: about?.name)
        let newTicketVC = Support.shared.newTicketViewController(reporter: currentIdentity, profile: profile)
        guard let controller = newTicketVC else {
            AppController.shared.alert(
                title: Localized.error.text,
                message: Localized.Error.supportNotConfigured.text,
                cancelTitle: Localized.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }

    func hashtagTapped(_ hashtag: Hashtag) {
        AppController.shared.open(string: hashtag.string)
    }

    func socialTraitTapped(_ trait: SocialStatsView.Trait) {
        switch trait {
        case .followers:
            AppController.shared.push(FollowerTableViewController(identity: identity))
        case .follows:
            AppController.shared.push(FollowingTableViewController(identity: identity))
        default:
            break
        }
    }

    func didDismiss() {
        AppController.shared.dismiss(animated: true)
    }

    func didDismissError() {
        errorMessage = nil
        didDismiss()
    }

    func shareThisProfile() {
        Analytics.shared.trackDidSelectAction(actionName: "share_profile")

        if let imageMetadata = about?.image, let image = Caches.blobs.image(for: imageMetadata.link) {
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )
            activityController.configurePopover(from: nil)
            AppController.shared.present(activityController, animated: true)
            return
        }

        let nameOrIdentity = about?.name ?? identity
        let text = Localized.shareThisProfileText.text([
            "who": nameOrIdentity,
            "link": identity.publicLink?.absoluteString ?? ""
        ])

        let activityController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        activityController.configurePopover(from: nil)
        AppController.shared.present(activityController, animated: true)
    }

    func sharePublicIdentifier() {
        Analytics.shared.trackDidSelectAction(actionName: "share_public_identifier")

        let activityController = UIActivityViewController(
            activityItems: [self.identity],
            applicationActivities: nil
        )
        activityController.configurePopover(from: nil)
        AppController.shared.present(activityController, animated: true)
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
                    let followers: [Identity] = try await Bots.current.followers(identity: currentIdentity)
                    let followings: [Identity] = try await Bots.current.followings(identity: currentIdentity)
                    let blocks = try await Bots.current.blocks(identity: currentIdentity)
                    let relationship = Relationship(from: currentIdentity, to: identity)
                    relationship.isFollowing = followings.contains(identity)
                    relationship.isBlocking = blocks.contains(identity)
                    relationship.isFollowedBy = followers.contains(identity)
                    await self?.updateRelationship(relationship)
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await self?.updateErrorMessage(error.localizedDescription)
                }
            }

            do {
                let followers: [Identity] = try await Bots.current.followers(identity: identity)
                let someFollowers = try await Bots.current.abouts(identities: Array(followers.prefix(2)))
                let followings: [Identity] = try await Bots.current.followings(identity: identity)
                let someFollowings = try await Bots.current.abouts(identities: Array(followings.prefix(2)))
                let blocks = try await Bots.current.blocks(identity: identity)
                let someBlocks = try await Bots.current.abouts(identities: Array(blocks.prefix(2)))
                let pubs = try await Bots.current.pubs(joinedBy: identity).map { $0.address.key }
                let somePubs = try await Bots.current.abouts(identities: Array(pubs.prefix(2)))
                await self?.updateSocialStats(ExtendedSocialStats(
                    numberOfFollowers: followers.count,
                    followers: someFollowers.map { $0?.image },
                    numberOfFollows: followings.count,
                    follows: someFollowings.map { $0?.image },
                    numberOfBlocks: blocks.count,
                    blocks: someBlocks.map { $0?.image },
                    numberOfPubServers: pubs.count,
                    pubServers: somePubs.map { $0?.image }
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
