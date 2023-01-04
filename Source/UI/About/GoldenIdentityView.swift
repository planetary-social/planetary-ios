//
//  GoldenIdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 3/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct GoldenIdentityView: View {

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

    private let goldenRatio: CGFloat = 0.618

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

    private var shouldShowBio: Bool {
        if let about = about {
            return about.description?.isEmpty == false
        }
        return true
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            BlobGalleryView(blobs: [Blob(identifier: about?.image?.identifier ?? .null)])
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            Text(about?.nameOrIdentity ?? identity)
                .padding(EdgeInsets(top: 9, leading: 0, bottom: 0, trailing: 0))
                .lineLimit(1)
                .foregroundColor(.primaryTxt)
                .font(.headline)
            if shouldShowBio {
                BioView(bio: about?.description, lineLimit: 2, showReadMoreIfNeeded: false)
                    .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
            }
            if let hashtags = hashtags, !hashtags.isEmpty {
                Text(hashtags.map { $0.string }.joined(separator: " ").parseMarkdown())
                    .font(.subheadline)
                    .foregroundLinearGradient(.horizontalAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0))
            }
            Text(attributedSocialStats(from: socialStats ?? .zero))
                .font(.footnote)
                .foregroundColor(Color.secondaryTxt)
                .redacted(reason: socialStats == nil ? .placeholder : [])
                .padding(EdgeInsets(top: 5, leading: 0, bottom: 10, trailing: 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(goldenRatio, contentMode: ContentMode.fill)
        .background(
            LinearGradient(
                colors: [Color.cardBgTop, Color.cardBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(15)
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { output in
            guard let notifiedRelationship = output.relationship, notifiedRelationship.other == identity else {
                return
            }
            relationship = notifiedRelationship
        }
        .task {
            loadAbout()
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

struct GoldenIdentityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                Group {
                    GoldenIdentityView(identity: "@unset")
                    GoldenIdentityView(identity: .null)
                }
                .background(Color.cardBackground)
            }
            VStack {
                GoldenIdentityView(identity: "@unset")
                GoldenIdentityView(identity: .null)
            }
            .preferredColorScheme(.dark)
        }
        .padding(10)
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
