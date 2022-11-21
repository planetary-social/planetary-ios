//
//  CompactIdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 28/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

@MainActor
struct CompactIdentityView: View {

    var identity: Identity

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var about: About?

    @State
    private var socialStats: SocialStats?

    @State
    private var hashtags: [Hashtag]?

    @State
    private var relationship: Relationship?

    @State
    var isToggling = false

    func attributedSocialStats(from socialStats: SocialStats) -> AttributedString {
        let numberOfFollowers = socialStats.numberOfFollowers
        let numberOfFollows = socialStats.numberOfFollows
        let string = Localized.followStats.text

        var attributeContainer = AttributeContainer()
        attributeContainer.foregroundColor = .primaryTxt

        var attributedString = AttributedString(string)
        if let range = attributedString.range(of: "{{numberOfFollows}}") {
            attributedString.replaceSubrange(
                range,
                with: AttributedString("\(numberOfFollows)", attributes: attributeContainer)
            )
        }
        if let range = attributedString.range(of: "{{numberOfFollowers}}") {
            attributedString.replaceSubrange(
                range,
                with: AttributedString("\(numberOfFollowers)", attributes: attributeContainer)
            )
        }
        return attributedString
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Circle()
                .fill(LinearGradient.diagonalAccent)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                .frame(width: 92, height: 92)
                .overlay(AvatarView(metadata: about?.image, size: 87))
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text(about?.nameOrIdentity ?? identity)
                            .lineLimit(1)
                            .foregroundColor(.primaryTxt)
                            .font(.headline)
                        Text(identity.prefix(7))
                            .font(.footnote)
                            .foregroundColor(.secondaryTxt)
                    }
                    Spacer()
                    Button {
                        Analytics.shared.trackDidTapButton(buttonName: "follow")
                        toggleRelationship()
                    } label: {
                        RelationshipLabel(relationship: isToggling ? nil : relationship, compact: true)
                    }
                    .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                }
                Text(attributedSocialStats(from: socialStats ?? .zero))
                    .font(.footnote)
                    .foregroundColor(Color.secondaryTxt)
                    .redacted(reason: socialStats == nil ? .placeholder : [])
                if let hashtags = hashtags, !hashtags.isEmpty {
                    Text(hashtags.map{$0.string}.joined(separator: " ").parseMarkdown())
                        .font(.subheadline)
                        .foregroundLinearGradient(.horizontalAccent)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { output in
            guard let notifiedRelationship = output.relationship, notifiedRelationship.other == identity else {
                return
            }
            relationship = notifiedRelationship
        }
        .task {
            Task.detached {
                let bot = await botRepository.current
                do {
                    let result = try await bot.about(identity: identity)
                    await MainActor.run {
                        about = result
                    }
                } catch {
                    await MainActor.run {
                        about = About(about: identity)
                    }
                }
                do {
                    let result = try await bot.socialStats(for: identity)
                    await MainActor.run {
                        socialStats = result
                    }
                } catch {
                    await MainActor.run {
                        socialStats = .zero
                    }
                }
                do {
                    let result = try await bot.hashtags(usedBy: identity, limit: 3)
                    await MainActor.run {
                        hashtags = result
                    }
                } catch {
                    await MainActor.run {
                        hashtags = []
                    }
                }
            }
            loadRelationship()
        }
    }

    private func loadRelationship() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            if let currentIdentity = bot.identity {
                do {
                    let result = try await bot.relationship(from: currentIdentity, to: identity)
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

    private func toggleRelationship() {
        guard let relationshipToUpdate = relationship else {
            return
        }
        isToggling = true
        Task.detached {
            let bot = await botRepository.current
            let pubs = (AppConfiguration.current?.communityPubs ?? []) + (AppConfiguration.current?.systemPubs ?? [])
            let star = pubs.first { $0.feed == relationshipToUpdate.other }
            do {
                if let star = star {
                    try await bot.join(star: star)
                    Analytics.shared.trackDidFollowPub()
                    relationshipToUpdate.isFollowing = true
                } else if relationshipToUpdate.isBlocking {
                    try await bot.unblock(identity: relationshipToUpdate.other)
                    Analytics.shared.trackDidUnblockIdentity()
                    relationshipToUpdate.isBlocking = false
                } else {
                    if relationshipToUpdate.isFollowing {
                        try await bot.unfollow(identity: relationshipToUpdate.other)
                        Analytics.shared.trackDidUnfollowIdentity()
                        relationshipToUpdate.isFollowing = false
                    } else {
                        try await bot.follow(identity: relationshipToUpdate.other)
                        Analytics.shared.trackDidFollowIdentity()
                        relationshipToUpdate.isFollowing = true
                    }
                }
                await MainActor.run {
                    isToggling = false
                    NotificationCenter.default.post(
                        name: .didUpdateRelationship,
                        object: nil,
                        userInfo: [Relationship.infoKey: relationshipToUpdate]
                    )
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    isToggling = true
                    AppController.shared.alert(error: error)
                }
            }
        }
    }
}

struct CompactIdentityView_Previews: PreviewProvider {
    static let post: Post = {
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        Caches.blobs.update(UIImage(named: "avatar2") ?? .remove, for: "&avatar2")
        Caches.blobs.update(UIImage(named: "avatar3") ?? .remove, for: "&avatar3")
        Caches.blobs.update(UIImage(named: "avatar4") ?? .remove, for: "&avatar4")
        Caches.blobs.update(UIImage(named: "avatar5") ?? .remove, for: "&avatar5")
        let post = Post(
            blobs: [
                Blob(identifier: "&avatar1"),
                Blob(identifier: "&avatar2"),
                Blob(identifier: "&avatar3"),
                Blob(identifier: "&avatar4"),
                Blob(identifier: "&avatar5")
            ],
            branches: nil,
            hashtags: nil,
            mentions: nil,
            root: nil,
            text: "Hello"
        )
        return post
    }()

    static var previews: some View {
        CompactIdentityView(identity: .null)
            .environmentObject(BotRepository.shared)
            .previewLayout(.sizeThatFits)
            .preferredColorScheme(.light)
    }
}
