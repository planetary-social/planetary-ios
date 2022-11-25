//
//  IdentityOptionsButton.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import Support
import SwiftUI

struct IdentityOptionsButton: View {

    var identity: Identity

    var name: String?

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var showingOptions = false

    @State
    private var showingManageAlias = false

    private var isSelf: Bool {
        botRepository.current.identity == identity
    }

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image("icon-options-off")
        }
        .confirmationDialog(Localized.share.text, isPresented: $showingOptions) {
            if isSelf {
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

struct IdentityOptionsButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                IdentityOptionsButton(identity: .null)
                IdentityOptionsButton(identity: "@unset")
            }
            VStack {
                IdentityOptionsButton(identity: .null)
                IdentityOptionsButton(identity: "@unset")
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
