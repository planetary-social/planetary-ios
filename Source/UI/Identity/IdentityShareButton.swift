//
//  IdentityShareButton.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import SwiftUI

struct IdentityShareButton: View {

    var identity: Identity

    @State
    private var showingOptions = false

    @State
    private var showingShare = false

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

struct IdentityShareButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IdentityShareButton(identity: .null)
            IdentityShareButton(identity: .null)
                .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
    }
}
