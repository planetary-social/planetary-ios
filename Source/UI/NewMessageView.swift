//
//  NewMessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct NewMessageView: View {

    var message: Message

    var attributedHeader: AttributedString? {
        guard let name = message.metadata.author.about?.nameOrIdentity else {
            return nil
        }
        var localized: Localized
        switch message.contentType {
        case .post:
            guard let post = message.content.post else {
                return nil
            }
            if post.isRoot {
                localized = .posted
            } else {
                localized = .replied
            }
        case .contact:
            guard let contact = message.content.contact else {
                return nil
            }
            if contact.isFollowing {
                localized = .startedFollowing
            } else if contact.isBlocking {
                localized = .blocked
            } else {
                return nil
            }
        default:
            return nil
        }
        let string = localized.text(["somebody": "**\(name)**"])
        do {
            return try AttributedString(markdown: string)
        } catch {
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                ImageMetadataView(metadata: message.metadata.author.about?.image)
                    .cornerRadius(99)
                    .frame(width: 24, height: 24)
                    .scaledToFill()
                if let header = attributedHeader {
                    Text(header)
                        .font(Font.caption)
                        .foregroundColor(Color.secondaryTxt)
                }
            }
            .padding(10)
            Divider().background(Color(hex: "#a68782").opacity(0.15))
            if let post = message.content.post {
                PostView(post: post)
            } else if let contact = message.content.contact {
                NewContactView(identity: contact.contact)
            }
            HStack {
                HStack {
                    Text("Post a reply")
                        .foregroundColor(Color.secondaryTxt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image.navIconCamera
                        .renderingMode(.template)
                        .foregroundColor(.secondaryTxt)
                }
                .frame(maxWidth: .infinity, idealHeight: 35)
                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .background(Color(hex: "#F4EBEA"))
                .cornerRadius(18)
            }.padding(15)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "#fff8f7"), Color(hex: "#fdf7f6")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
    }
}

struct NewMessageView_Previews: PreviewProvider {
    static let message: Message = {
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
        let content = Content(from: post)
        let value = MessageValue(
            author: .null,
            content: content,
            hash: "",
            previous: nil,
            sequence: 0,
            signature: .null,
            claimedTimestamp: 0
        )
        var message = Message(
            key: .null,
            value: value,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(count: 0, abouts: Set()),
            isPrivate: false
        )
        return message
    }()

    static var previews: some View {
        NewMessageView(message: message).preferredColorScheme(.light)

    }
}
