//
//  IdentityListView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct IdentityListView: View {

    @EnvironmentObject
    var bot: BotRepository

    @SwiftUI.Environment(\.dismiss)
    private var dismiss

    var identities: [Identity]

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 1) {
                ForEach(identities, id: \.self) { identity in
                    CompactIdentityView(identity: identity)
                        .onTapGesture {
                            dismiss()
                            AppController.shared.open(identity: identity)
                        }
                        .background(
                            Color.cardBackground
                        )
                }
            }
        }
        .background(Color.appBg)
    }
}

struct IdentityListView_Previews: PreviewProvider {

    static var sample: Identity {
        Identity.null
    }

    static var previews: some View {
        NavigationView {
            IdentityListView(identities: [sample, sample])
                .environmentObject(BotRepository.shared)
        }
        NavigationView {
            IdentityListView(identities: [sample, sample])
                .environmentObject(BotRepository.shared)
        }
        .preferredColorScheme(.dark)
    }
}
