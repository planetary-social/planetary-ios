//
//  GoldenIdentityView.swift
//  Planetary
//
//  Created by Martin Dutra on 3/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays the information for an identity in a rectangle in which its sides respect the golden ratio.
///
/// IdentityCard uses this view when the card's style is set to golden.
struct GoldenIdentityView: View {
    
    var identity: Identity

    var about: About?

    var socialStats: SocialStats?

    var hashtags: [Hashtag]?

    @EnvironmentObject
    private var botRepository: BotRepository

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            BlobGalleryView(blobs: [Blob(identifier: about?.image?.identifier ?? .null)])
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            Text(about?.nameOrIdentity ?? identity)
                .padding(EdgeInsets(top: 9, leading: 10, bottom: 5, trailing: 10))
                .lineLimit(1)
                .foregroundColor(.primaryTxt)
                .font(.subheadline)
            Text(identity.prefix(7))
                .foregroundColor(.secondaryTxt)
                .font(.footnote)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            if shouldShowBio {
                Text(bio)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .allowsHitTesting(false)
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    .placeholder(when: about == nil) {
                        Text(String.loremIpsum(1))
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                            .redacted(reason: .placeholder)
                    }
            }
            if let hashtags = hashtags, !hashtags.isEmpty {
                Text(hashtags.map { $0.string }.joined(separator: " ").parseMarkdown(fontStyle: .small))
                    .foregroundLinearGradient(.horizontalAccent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
            }
            Spacer(minLength: 9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(goldenRatio, contentMode: ContentMode.fill)
        .background(
            LinearGradient.cardGradient
        )
        .cornerRadius(15)
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    private let goldenRatio: CGFloat = 0.618

    private var shouldShowBio: Bool {
        if let about = about {
            return about.description?.isEmpty == false
        }
        return true
    }

    private var bio: AttributedString {
        about?.description?.parseMarkdown(fontStyle: .small) ?? AttributedString()
    }
}

struct GoldenIdentityView_Previews: PreviewProvider {
    static var about: About {
        About(about: .null, name: "Mario", description: .loremIpsum(1), imageLink: nil)
    }
    static var hashtags: [Hashtag] {
        [Hashtag(name: "Design"), Hashtag(name: "Architecture"), Hashtag(name: "Retro")]
    }
    static var view: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                Group {
                    GoldenIdentityView(identity: "@unset")
                    GoldenIdentityView(identity: "@unset", about: about)
                    GoldenIdentityView(identity: "@unset", hashtags: hashtags)
                    GoldenIdentityView(identity: "@unset", about: about, hashtags: hashtags)
                }
                .background(Color.cardBackground)
            }
        }
    }
    static var previews: some View {
        Group {
            view
            view.preferredColorScheme(.dark)
        }
        .padding(10)
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
