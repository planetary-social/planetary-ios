//
//  NewContactView.swift
//  Planetary
//
//  Created by Martin Dutra on 28/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct NewContactView: View {

    var identity: Identity

    @State fileprivate var about: About?
    @State fileprivate var relationship: Relationship?

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#F08508"), Color(hex: "#F43F75")],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                .frame(width: 92, height: 92)
                .overlay(
                    ImageMetadataView(metadata: about?.image)
                        .cornerRadius(99)
                        .frame(width: 87, height: 87)
                        .scaledToFill()
                )
            VStack(alignment: .leading, spacing: 6) {
                Text(about?.nameOrIdentity ?? identity)
                    .foregroundColor(Color("primary-txt"))
                    .font(.system(size: 20, weight: .semibold))
                HStack {
                    Text(identity.prefix(7))
                        .font(.system(size: 12))
                        .foregroundColor(Color("secondary-txt"))
                }
                RelationshipView(relationship: relationship) {

                }
                .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task {
            Task.detached {
                do {
                    about = try await Bots.current.about(identity: identity)
                } catch {

                }
                if let currentIdentity = Bots.current.identity {
                    do {
                        relationship = try await Bots.current.relationship(from: currentIdentity, to: identity)
                    } catch {

                    }
                }

            }

        }
    }
}

struct NewContactView_Previews: PreviewProvider {
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
        NewContactView(identity: .null).previewLayout(.sizeThatFits).preferredColorScheme(.light)

    }
}
