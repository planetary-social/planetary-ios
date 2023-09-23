//
//  IdentityListView.swift
//  Planetary
//
//  Created by Martin Dutra on 7/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct IdentityListView: View {

    var identities: [Identity]

    var selectionHandler: ((Identity) -> Void)?

    @State
    var filteredIdentities: [Identity]

    init(identities: [Identity], selectionHandler: ((Identity) -> Void)? = nil) {
        self.identities = identities
        self.filteredIdentities = identities
        self.selectionHandler = selectionHandler
    }

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    @StateObject
    private var searchTextObserver = SearchTextFieldObserver()

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 1) {
                ForEach(filteredIdentities, id: \.self) { identity in
                    IdentityCard(identity: identity, style: .compact)
                        .onTapGesture {
                            if let selectionHandler = selectionHandler {
                                selectionHandler(identity)
                            } else {
                                appController.open(identity: identity)
                            }
                        }
                        .background(
                            Color.cardBackground
                        )
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: searchTextObserver.debouncedText) { newValue in
            search(for: newValue)
        }
        .searchable(text: $searchTextObserver.text, placement: .navigationBarDrawer(displayMode: (.always)))
        .disableAutocorrection(true)
        .background(Color.appBg)
    }

    private func search(for query: String) {
        guard !query.isEmpty else {
            filteredIdentities = identities
            return
        }
        let bot = botRepository.current
        let identities = identities
        Task.detached(priority: .userInitiated) {
            do {
                let foundIdentities = try await bot.abouts(matching: query).map { $0.identity }
                let intersectedIdentities = foundIdentities.filter { identities.contains($0) }
                await MainActor.run {
                    filteredIdentities = intersectedIdentities
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
            }
        }
    }
}

struct IdentityListView_Previews: PreviewProvider {

    static var sample: Identity {
        Identity.null
    }

    static var previews: some View {
        Group {
            NavigationView {
                IdentityListView(identities: [sample, "@unset"])
            }
            NavigationView {
                IdentityListView(identities: [sample, "@unset"])
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake, appController: .shared)
    }
}
