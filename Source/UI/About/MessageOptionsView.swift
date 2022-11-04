//
//  MessageOptionsView.swift
//  Planetary
//
//  Created by Martin Dutra on 4/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import SwiftUI

struct MessageOptionsView: View {

    var message: Message

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    fileprivate var showingOptions = false

    @State
    fileprivate var showingShare = false

    @State
    fileprivate var showingSource = false

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image("icon-options-off")
        }
        .confirmationDialog(Localized.share.text, isPresented: $showingOptions) {
            Button(Localized.copyMessageIdentifier.text) {
                Analytics.shared.trackDidSelectAction(actionName: "copy_message_identifier")
                copyMessageIdentifier()
            }
            Button(Localized.shareThisMessage.text) {
                Analytics.shared.trackDidSelectAction(actionName: "share_message")
                showingShare = true
            }
            Button(Localized.viewSource.text) {
                Analytics.shared.trackDidSelectAction(actionName: "view_message_source")
                showingSource = true
            }
            Button(Localized.reportPost.text, role: .destructive) {
                Analytics.shared.trackDidSelectAction(actionName: "report_post")
                reportPost()
            }
        }
        .sheet(isPresented: $showingSource) {
            RawMessageView(viewModel: RawMessageCoordinator(message: message, bot: botRepository.current))
        }
        .sheet(isPresented: $showingShare) {
            if let url = message.key.publicLink {
                ActivityViewController(activityItems: [url])
            } else {
                ActivityViewController(activityItems: [])
            }
        }
    }

    func copyMessageIdentifier() {
        UIPasteboard.general.string = message.key
        AppController.shared.showToast(Localized.identifierCopied.text)
    }

    func reportPost() {
        AppController.shared.report(message, in: nil, from: message.author)
    }
}

struct MessageOptionsView_Previews: PreviewProvider {
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
        MessageOptionsView(message: message).preferredColorScheme(.light)
    }
}
