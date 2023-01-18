//
//  GoldenPostView.swift
//  Planetary
//
//  Created by Martin Dutra on 29/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct GoldenPostView: View {

    let identifier: MessageIdentifier

    var author: About

    var post: Post {
        didSet {
            blobs = post.anyBlobs
        }
    }

    init(identifier: MessageIdentifier, post: Post, author: About) {
        self.identifier = identifier
        self.post = post
        self.blobs = post.anyBlobs
        self.markdown = post.text.parseMarkdown(fontStyle: post.isTextOnly ? .large : .compact)
        self.author = author
    }

    private var blobs: [Blob]

    private var markdown: AttributedString

    @EnvironmentObject
    private var appController: AppController

    private let goldenRatio: CGFloat = 0.618

    var text: some View {
        Text(markdown)
            .foregroundColor(.primaryTxt)
            .accentColor(.accent)
    }

    var footer: some View {
        HStack(alignment: .center) {
            Button {
                appController.open(identity: author.identity)
            } label: {
                HStack(alignment: .center) {
                    AvatarView(metadata: author.image, size: 20)
                    if !post.isBlobOnly {
                        Text(author.displayName)
                            .lineLimit(1)
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if post.isBlobOnly {
                ZStack(alignment: .bottom) {
                    BlobGalleryView(blobs: blobs, aspectRatio: goldenRatio)
                        .allowsHitTesting(false)
                    footer
                }
            } else {
                if !blobs.isEmpty {
                    BlobGalleryView(blobs: blobs)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                }

                if post.isTextOnly {
                    text
                        .padding(EdgeInsets(top: 15, leading: 10, bottom: 15, trailing: 10))
                } else {
                    text
                        .padding(EdgeInsets(top: 8, leading: 10, bottom: 0, trailing: 10))
                }
                Spacer(minLength: 0)
                footer
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(goldenRatio, contentMode: ContentMode.fill)
    }
}

struct GoldenPostView_Previews: PreviewProvider {
    static var shortPost: Post {
        let post = Post(
            blobs: nil,
            branches: nil,
            hashtags: nil,
            mentions: nil,
            root: nil,
            text: .loremIpsum(1)
        )
        return post
    }
    static var shortPostWithBlobs: Post {
        Caches.blobs.update(UIImage(named: "test") ?? .remove, for: "&test")
        let post = Post(
            blobs: [
                Blob(identifier: "&test")
            ],
            branches: nil,
            hashtags: nil,
            mentions: nil,
            root: nil,
            text: .loremIpsum(words: 1)
        )
        return post
    }
    static var postWithBlobsOnly: Post {
        Caches.blobs.update(UIImage(named: "test") ?? .remove, for: "&test")
        let post = Post(
            blobs: [
                Blob(identifier: "&test")
            ],
            branches: nil,
            hashtags: nil,
            mentions: nil,
            root: nil,
            text: ""
        )
        return post
    }
    static var author: About {
        Caches.blobs.update(UIImage(named: "avatar1") ?? .remove, for: "&avatar1")
        return About(
            identity: .null,
            name: "Mario",
            description: nil,
            image: ImageMetadata(link: "&avatar1"),
            publicWebHosting: nil
        )
    }

    static var previews: some View {
        Group {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                Group {
                    GoldenPostView(identifier: .null, post: shortPost, author: author)
                    GoldenPostView(identifier: .null, post: shortPostWithBlobs, author: author)
                    GoldenPostView(identifier: .null, post: postWithBlobsOnly, author: author)
                }
                .background(Color.cardBackground)
            }
            VStack {
                GoldenPostView(identifier: .null, post: shortPost, author: author)
                GoldenPostView(identifier: .null, post: shortPostWithBlobs, author: author)
            }
            .preferredColorScheme(.dark)
        }
        .padding(10)
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
