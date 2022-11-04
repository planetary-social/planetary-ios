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

    @State
    private var shouldShowReadMore = false

    @State
    private var intrinsicSize = CGSize.zero

    @State
    private var truncatedSize = CGSize.zero

    func updateShouldShowReadMore() {
        shouldShowReadMore = intrinsicSize != truncatedSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(post.text.parseMarkdown())
                .lineLimit(5)
                .font(.body)
                .foregroundColor(Color.primaryTxt)
                .accentColor(Color.accentTxt)
                .padding(15)
                .background {
                    GeometryReader { geometryProxy in
                        Color.clear.preference(key: TruncatedSizePreferenceKey.self, value: geometryProxy.size)
                    }
                }
                .onPreferenceChange(TruncatedSizePreferenceKey.self) { newSize in
                    truncatedSize = newSize
                    updateShouldShowReadMore()
                }
                .background {
                    Text(post.text.parseMarkdown())
                        .font(.body)
                        .padding(15)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .background {
                            GeometryReader { geometryProxy in
                                Color.clear.preference(key: IntrinsicSizePreferenceKey.self, value: geometryProxy.size)
                            }
                        }
                        .onPreferenceChange(IntrinsicSizePreferenceKey.self) { newSize in
                            intrinsicSize = newSize
                            updateShouldShowReadMore()
                        }
                }
            if shouldShowReadMore {
                ZStack(alignment: .center) {
                    Text("Read more".uppercased())
                        .font(.caption)
                        .foregroundColor(.secondaryTxt)
                        .padding(EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6))
                        .background(Color.hashtagBg)
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity)
            }
//            if !blobs.isEmpty {
//                TabView {
//                    ForEach(blobs) { blob in
//                        ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
//                            .onTapGesture {
//                                AppController.shared.open(string: blob.identifier)
//                            }
//                    }
//                }
//                .tabViewStyle(.page)
//                .aspectRatio(1, contentMode: .fit)
//            }
        }
    }
}

fileprivate struct IntrinsicSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

fileprivate struct TruncatedSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

struct PostView_Previews: PreviewProvider {
    static let post: Post = {
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
            text: .loremIpsum(5)
        )
        return post
    }()

    static var previews: some View {
        PostView(post: post).previewLayout(.sizeThatFits).preferredColorScheme(.light)

    }
}
