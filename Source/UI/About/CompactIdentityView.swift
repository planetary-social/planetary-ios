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

    private var isSelf: Bool {
        botRepository.current.identity == identity
    }

    private func attributedSocialStats(from socialStats: SocialStats) -> AttributedString {
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
                    if !isSelf {
                        RelationshipButton(relationship: relationship, compact: true)
                    }
                }
                Text(attributedSocialStats(from: socialStats ?? .zero))
                    .font(.footnote)
                    .foregroundColor(Color.secondaryTxt)
                    .redacted(reason: socialStats == nil ? .placeholder : [])
                if let hashtags = hashtags, !hashtags.isEmpty {
                    Text(hashtags.map { $0.string }.joined(separator: " ").parseMarkdown())
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
            loadAbout()
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
                    about = About(about: identity)
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
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    hashtags = []
                }
            }
        }
    }

    private func loadSocialStats() {
        Task.detached {
            let identityToLoad = await identity
            let bot = await botRepository.current
            do {
                let result = try await bot.socialStats(for: identityToLoad)
                await MainActor.run {
                    socialStats = result
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    socialStats = .zero
                }
            }
        }
    }
}

struct CompactIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                CompactIdentityView(identity: "@unset")
                CompactIdentityView(identity: .null)
            }
            VStack {
                CompactIdentityView(identity: "@unset")
                CompactIdentityView(identity: .null)
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
