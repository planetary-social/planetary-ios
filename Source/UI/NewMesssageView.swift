//
//  NewMesssageView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct NewMesssageView: View {

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
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                ImageMetadataView(metadata: message.metadata.author.about?.image)
                    .cornerRadius(99)
                    .frame(width: 24, height: 24)
                    .scaledToFill()
                if let header = attributedHeader {
                    Text(header)
                        .font(.body)
                        .foregroundColor(Color.primaryTxt)
                }
            }
            .padding(10)
            Divider().background(Color(hex: "#a68782").opacity(0.15))
            Text(message.content.post?.text.parseMarkdown() ?? "This is not a post")
                .font(.body)
                .foregroundColor(Color.primaryTxt)
                .lineLimit(5)
                .padding(15)
            if let blob = message.content.post?.anyBlobs.first {
                ImageMetadataView(metadata: ImageMetadata(link: blob.identifier))
                    .aspectRatio(1, contentMode: .fill)
                    .onTapGesture {
                        AppController.shared.open(string: blob.identifier)
                    }
            }
            HStack {
                Text("Post a reply")
                    .foregroundColor(Color.primaryTxt).padding(8).frame(maxWidth: .infinity, idealHeight: 35).background(Color(hex: "#F4EBEA")).cornerRadius(18)
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

struct NewMesssageView_Previews: PreviewProvider {
    static let message: Message = {
        let post = Post(text: "Hello")
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
        NewMesssageView(message: message).preferredColorScheme(.light)

    }
}
