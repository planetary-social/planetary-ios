//
//  MessageOptionsButton.swift
//  Planetary
//
//  Created by Martin Dutra on 4/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import SwiftUI

struct MessageOptionsButton: View {

    var message: Message

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var showingOptions = false

    @State
    private var showingShare = false

    @State
    private var showingSource = false

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image.iconOptions
                // This hack fixes a weird issue where the confirmationDialog wouldn't be shown sometimes. ¯\_(ツ)_/¯
                .background(showingOptions == true ? .clear : .clear)
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
            NavigationView {
                RawMessageView(viewModel: RawMessageController(message: message, bot: botRepository.current))
                    .navigationBarTitleDisplayMode(.inline)
            }
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
        var message = Message(
            key: .null,
            value: MessageValue(
                author: .null,
                content: Content(
                    from: Post(
                        blobs: nil,
                        branches: nil,
                        hashtags: nil,
                        mentions: nil,
                        root: nil,
                        text: .loremIpsum(1)
                    )
                ),
                hash: "",
                previous: nil,
                sequence: 0,
                signature: .null,
                claimedTimestamp: 0
            ),
            timestamp: 0
        )
        return message
    }()

    static var previews: some View {
        Group {
            MessageOptionsButton(message: message)
            MessageOptionsButton(message: message)
                .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
