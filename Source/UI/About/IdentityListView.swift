//
//  IdentityListView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct IdentityListView: View {

    var identities: [Identity]

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 1) {
                ForEach(identities, id: \.self) { identity in
                    CompactIdentityView(identity: identity)
                        .onTapGesture {
                            appController.open(identity: identity)
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
        Group {
            VStack {
                IdentityListView(identities: [sample, "@unset"])
            }
            VStack {
                IdentityListView(identities: [sample, "@unset"])
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
        .environmentObject(AppController.shared)
    }
}
