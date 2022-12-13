//
//  HashtagListView.swift
//  Planetary
//
//  Created by Martin Dutra on 30/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct HashtagListView: View {

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var helpDrawerState: HelpDrawerState

    private let helpDrawer = HelpDrawer.hashtags

    @State
    private var allHashtags: [Hashtag]?

    @State
    private var filteredHashtags: [Hashtag]?

    @State
    private var searchText = ""

    @SwiftUI.Environment(\.isSearching)
    private var isSearching

    @State
    private var errorMessage: String?

    private var shouldShowAlert: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { _ in
            errorMessage = nil
        }
    }

    var body: some View {
        Group {
            if let hashtags = filteredHashtags {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(hashtags) { hashtag in
                            NavigationLink {
                                HashtagView(hashtag: hashtag)
                                    .environmentObject(botRepository)
                            } label: {
                                CompactHashtagView(hashtag: hashtag)
                            }
                        }
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: (.always)))
                .disableAutocorrection(true)
                .onChange(of: searchText) { value in
                    if value.isEmpty && !isSearching {
                        filter()
                    }
                }
                .onSubmit(of: .search) {
                    filter()
                }
            } else {
                ZStack {
                    PeerConnectionAnimationView(peerCount: 3, color: UIColor.secondaryTxt)
                        .scaleEffect(1.3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .background(Color.appBg)
        .navigationTitle(Localized.channels.text)
        .toolbar {
            Button {
                helpDrawerState.isShowingHashtagsHelpDrawer = true
            } label: {
                Image.navIconHelp
            }
            .popover(isPresented: $helpDrawerState.isShowingHashtagsHelpDrawer) {
                Group {
                    if #available(iOS 16.0, *) {
                        HelpDrawerCoordinator.helpDrawerView(for: helpDrawer) {
                            helpDrawerState.isShowingHashtagsHelpDrawer = false
                        }
                        .presentationDetents([.medium])
                    } else {
                        HelpDrawerCoordinator.helpDrawerView(for: helpDrawer) {
                            helpDrawerState.isShowingHashtagsHelpDrawer = false
                        }
                    }
                }
                .onAppear {
                    Analytics.shared.trackDidShowScreen(screenName: helpDrawer.screenName)
                    HelpDrawerCoordinator.didShowHelp(for: helpDrawer)
                }
            }
        }
        .alert(
            Localized.error.text,
            isPresented: shouldShowAlert,
            actions: {
                Button(Localized.tryAgain.text) {
                    Task {
                        await loadHashtags()
                    }
                }
                Button(Localized.cancel.text, role: .cancel) {
                    shouldShowAlert.wrappedValue = false
                }
            },
            message: {
                Text(errorMessage ?? "")
            }
        )
        .task {
            await loadHashtags()
        }
        .refreshable {
            await loadHashtags()
        }
        .onAppear {
            CrashReporting.shared.record("Did Show Channels")
            Analytics.shared.trackDidShowScreen(screenName: "channels")
            HelpDrawerCoordinator.showFirstTimeHelp(for: helpDrawer, state: helpDrawerState)
        }
    }

    private func loadHashtags() async {
        let bot = botRepository.current
        do {
            let result = try await bot.hashtags()
            await MainActor.run {
                allHashtags = result
                filter()
            }
        } catch {
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.shared.optional(error)
            await MainActor.run {
                errorMessage = error.localizedDescription
                allHashtags = []
                filter()
            }
        }
    }

    private func filter() {
        guard let allHashtags = allHashtags else {
            filteredHashtags = nil
            return
        }
        if searchText.isEmpty {
            filteredHashtags = allHashtags
        } else {
            filteredHashtags = allHashtags.filter {
                $0.string.localizedStandardContains(searchText)
            }
        }
    }
}

struct HashtagListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                HashtagListView()
            }
            NavigationView {
                HashtagListView()
            }
            .preferredColorScheme(.dark)
        }
        .environmentObject(BotRepository.fake)
        .environmentObject(HelpDrawerState())
    }
}
