//
//  IdentityShareView.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import SwiftUI

struct IdentityShareView: View {

    var identity: Identity

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    fileprivate var showingOptions = false

    @State
    fileprivate var showingShare = false

    var body: some View {
        Button {
            showingOptions = true
        } label: {
            Image("icon-share")
        }
        .confirmationDialog(Localized.share.text, isPresented: $showingOptions) {
            Button(Localized.copyPublicIdentifier.text) {
                Analytics.shared.trackDidSelectAction(actionName: "copy_public_identifier")
                copyPublicIdentifier()
            }
            Button(Localized.shareThisProfile.text) {
                Analytics.shared.trackDidSelectAction(actionName: "share_profile")
                showingShare = true
            }
        }
        .sheet(isPresented: $showingShare) {
            if let url = identity.publicLink {
                ActivityViewController(activityItems: [url])
            } else {
                ActivityViewController(activityItems: [])
            }
        }
    }

    func copyPublicIdentifier() {
        UIPasteboard.general.string = identity
        AppController.shared.showToast(Localized.identifierCopied.text)
    }
}

struct IdentityShareView_Previews: PreviewProvider {
    static var previews: some View {
        IdentityShareView(identity: .null).preferredColorScheme(.light)
    }
}
