//
//  CompactIdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 28/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

@MainActor
struct CompactIdentityView: View {

    @EnvironmentObject
    var botRepository: BotRepository

    var identity: Identity

    @State
    private var about: About?

    @State
    private var socialStats: SocialStats?

    @State
    private var hashtags: [Hashtag]?

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
                    RelationshipView(identity: identity, compact: true)
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
