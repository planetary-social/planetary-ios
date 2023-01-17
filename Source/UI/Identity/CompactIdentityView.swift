//
//  CompactIdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 28/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays the information for an identity in a rectangle.
///
/// IdentityCard uses this view when the card's style is set to compact.
struct CompactIdentityView: View {

    var identity: Identity

    var about: About?

    var socialStats: SocialStats?

    var hashtags: [Hashtag]?

    var relationship: Relationship?

    @EnvironmentObject
    private var botRepository: BotRepository

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
    }
}

struct CompactIdentityView_Previews: PreviewProvider {
    static var about: About {
        About(about: .null, name: "Mario")
    }
    static var socialStats: SocialStats {
        SocialStats(numberOfFollowers: 24, numberOfFollows: 12)
    }
    static var hashtags: [Hashtag] {
        [Hashtag(name: "Design"), Hashtag(name: "Architecture"), Hashtag(name: "Retro")]
    }
    static var relationship: Relationship {
        Relationship(from: .null, to: .null)
    }
    static var view: some View {
        ScrollView {
            VStack {
                CompactIdentityView(identity: "@unset")
                CompactIdentityView(identity: "@unset", about: about)
                CompactIdentityView(identity: "@unset", socialStats: socialStats)
                CompactIdentityView(identity: "@unset", hashtags: hashtags)
                CompactIdentityView(identity: "@unset", relationship: relationship)
                CompactIdentityView(
                    identity: "@unset",
                    about: about,
                    socialStats: socialStats,
                    hashtags: hashtags,
                    relationship: relationship
                )
                CompactIdentityView(identity: .null)
            }
        }
    }
    static var previews: some View {
        Group {
            view
            view.preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
