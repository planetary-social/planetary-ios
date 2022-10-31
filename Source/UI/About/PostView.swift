//
//  PostView.swift
//  Planetary
//
//  Created by Martin Dutra on 28/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct PostView: View {

    var post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(post.text.parseMarkdown())
                .font(.body)
                .foregroundColor(Color.primaryTxt)
                .accentColor(Color.accentTxt)
                .lineLimit(5)
                .padding(15)
            if let blobs = post.anyBlobs {
                TabView {
                    ForEach(blobs, id: \.self) { blob in
                        ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
                            .onTapGesture {
                                AppController.shared.open(string: blob.identifier)
                            }
                    }
                }
                .tabViewStyle(.page)
                .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

struct PostView_Previews: PreviewProvider {
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
        PostView(post: post).previewLayout(.sizeThatFits).preferredColorScheme(.light)

    }
}
