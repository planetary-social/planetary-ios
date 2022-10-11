//
//  IdentityCoordinator.swift
//  Planetary
//
//  Created by Martin Dutra on 30/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Analytics
import Logger

/// A coordinator for the `RawMessageView`
@MainActor class IdentityCoordinator: IdentityViewModel {

    @Published var identity: Identity

    private var bot: Bot

    @Published var about: About?

    @Published var socialStats: ExtendedSocialStats?

    @Published var hashtags: [Hashtag]?

    @Published var relationship: Relationship?

    @Published var loadingMessage: String?

    @Published var errorMessage: String?

    init(identity: Identity, bot: Bot) {
        self.identity = identity
        self.bot = bot
        loadAbout()
    }

    func followButtonTapped() {

    }

    func hashtagTapped(_ hashtag: Hashtag) {

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
        self.loadingMessage = nil
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
        self.loadingMessage = nil
    }

    private func loadAbout() {
        loadingMessage = Localized.loading.text
        Task.detached { [bot, identity, weak self] in
            do {
                let about = try await bot.about(identity: identity)
                await self?.updateAbout(about)
            } catch {
                Log.optional(error)
                await self?.updateErrorMessage(error.localizedDescription)
            }

            if let currentIdentity = Bots.current.identity {
                do {
                    let followers = try await Bots.current.followers(identity: currentIdentity)
                    let followings = try await Bots.current.followings(identity: currentIdentity)
                    let blocks = try await Bots.current.blocks(identity: currentIdentity)
                    let relationship = Relationship(from: currentIdentity, to: identity)
                    relationship.isFollowing = followings.contains(where: { $0.identity == identity })
                    relationship.isBlocking = blocks.contains(identity)
                    relationship.isFollowedBy = false
                    await self?.updateRelationship(relationship)
                } catch {

                }
            }
            do {
                let followers = try await Bots.current.followers(identity: identity)
                let followings = try await Bots.current.followings(identity: identity)
                let blocks = try await Bots.current.blocks(identity: identity)
                let someBlocks = try await Bots.current.abouts(identities: Array(blocks.prefix(2)))
                let pubs = try await Bots.current.pubs(joinedBy: identity)
                let somePubs = try await Bots.current.abouts(identities: pubs.prefix(2).map { $0.address.key })
                await self?.updateSocialStats(ExtendedSocialStats(
                    numberOfFollowers: followers.count,
                    followers: followers.prefix(2).compactMap { $0.image },
                    numberOfFollows: followings.count,
                    follows: followings.prefix(2).compactMap { $0.image },
                    numberOfBlocks: blocks.count,
                    blocks: someBlocks.compactMap { $0?.image },
                    numberOfPubServers: pubs.count,
                    pubServers: somePubs.compactMap { $0?.image }
                ))
            } catch {

            }

            var hashtags = [Hashtag]()
            do {
                hashtags = try await Bots.current.hashtags(usedBy: identity, limit: 3)
                await self?.updateHashtags(hashtags)
            } catch {

            }
        }
    }
}
