//
//  MessageHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 30/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageHeaderView: View {
    var message: Message

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        HStack(alignment: .center) {
            Button {
                appController.open(identity: message.author)
            } label: {
                HStack(alignment: .center) {
                    AvatarView(metadata: author.image, size: 24)
                    if let header = attributedHeader {
                        Text(header)
                            .lineLimit(1)
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            MessageOptionsButton(message: message)
        }
        .padding(10)
    }

    private var author: About {
        About(
            identity: message.author,
            name: message.metadata.author.about?.name,
            description: nil,
            image: message.metadata.author.about?.image,
            publicWebHosting: nil
        )
    }
    
    private var attributedHeader: AttributedString? {
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
        case .vote:
            localized = .reacted
        default:
            return nil
        }
        let string = localized.text(["somebody": "**\(author.displayName)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: author.displayName) {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }
}
