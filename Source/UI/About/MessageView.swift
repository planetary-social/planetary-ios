//
//  MessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageView: View {

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
            if contact.isBlocking {
                localized = .startedBlocking
            } else if contact.isFollowing {
                localized = .startedFollowing
            } else {
                localized = .stoppedFollowing
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
                AvatarView(metadata: message.metadata.author.about?.image, size: 24)
                if let header = attributedHeader {
                    Text(header)
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryTxt)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                MessageOptionsView(message: message)
            }
            .padding(10)
            Divider().background(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
            if let contact = message.content.contact {
                CompactIdentityView(identity: contact.contact)
                    .onTapGesture {
                        AppController.shared.open(identity: contact.contact)
                    }
            } else if let post = message.content.post {
                CompactPostView(post: post)
                    .onTapGesture {
                        AppController.shared.open(identifier: message.id)
                    }
                HStack {
                    HStack {
                        Text(Localized.postAReply.text)
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image.navIconCamera
                            .renderingMode(.template)
                            .foregroundColor(.accentTxt)
                    }
                    .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .frame(maxWidth: .infinity, idealHeight: 35)
                    .background(Color.postareplyBackground)
                    .cornerRadius(18)
                    .shadow(color: .postareplyShadowTop, radius: 0, x: 0, y: -1)
                    .shadow(color: .postareplyShadowBottom, radius: 0, x: 0, y: 1)
                }.padding(15)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.cardBgTop, Color.cardBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(20)
    }
}

struct MessageView_Previews: PreviewProvider {
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
            text: .loremIpsum(6)
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
        MessageView(message: message)
            .environmentObject(BotRepository.shared)
            .preferredColorScheme(.light)
        MessageView(message: message)
            .environmentObject(BotRepository.shared)
            .preferredColorScheme(.dark)
    }
}
