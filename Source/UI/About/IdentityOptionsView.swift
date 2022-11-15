//
//  IdentityOptionsView.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import Support
import SwiftUI

struct IdentityOptionsView: View {

    var identity: Identity

    var name: String?

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var showingOptions = false

    @State
    private var showingManageAlias = false

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image("icon-options-off")
        }
        .confirmationDialog(Localized.share.text, isPresented: $showingOptions) {
            if botRepository.current.identity == identity {
                Button(Localized.Alias.manageAliases.text) {
                    showingManageAlias = true
                }
            } else {
                Button(Localized.blockUser.text, role: .destructive) {
                    Analytics.shared.trackDidSelectAction(actionName: "block_identity")
                    blockUser()
                }
                Button(Localized.reportUser.text, role: .destructive) {
                    Analytics.shared.trackDidSelectAction(actionName: "report_user")
                    reportUser()
                }
            }
        }
        .sheet(isPresented: $showingManageAlias) {
            NavigationView {
                ManageAliasView(viewModel: RoomAliasController(bot: botRepository.current))
            }
        }
    }

    func blockUser() {
        AppController.shared.promptToBlock(identity, name: name)
    }

    func reportUser() {
        let reporter = botRepository.current.identity ?? .null
        let profile = AbusiveProfile(identifier: identity, name: name)
        guard let controller = Support.shared.newTicketViewController(reporter: reporter, profile: profile) else {
            AppController.shared.alert(
                title: Localized.error.text,
                message: Localized.Error.supportNotConfigured.text,
                cancelTitle: Localized.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }
}

struct IdentityOptionsView_Previews: PreviewProvider {
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
