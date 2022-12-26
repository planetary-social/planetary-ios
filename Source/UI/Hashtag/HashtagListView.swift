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

struct HashtagListView: View, HelpDrawerHost {

    init(helpDrawerState: HelpDrawerState) {
        self.helpDrawerState = helpDrawerState
    }
    
    @ObservedObject
    private var helpDrawerState: HelpDrawerState

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    let helpDrawerType = HelpDrawer.hashtags

    @SwiftUI.Environment(\.horizontalSizeClass)
    var horizontalSizeClass

    func dismissDrawer(completion: (() -> Void)?) {
        helpDrawerState.isShowingHashtagsHelpDrawer = false
        // Unfortunately, there is no good way to know when the popover dismissed in SwiftUI
        // So here I use a nasty simple trick to let the completion open the next drawer.
        // Fortunately, we can get rid of this after we migrate the remaining screens to SwiftUI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            completion?()
        }
    }

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
                                HashtagView(
                                    hashtag: hashtag,
                                    bot: botRepository.current
                                )
                                .injectAppEnvironment(botRepository: botRepository, appController: appController)
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
                LoadingView()
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
                        HelpDrawerCoordinator.helpDrawerView(for: self) {
                            helpDrawerState.isShowingHashtagsHelpDrawer = false
                        }
                        .presentationDetents([.medium])
                    } else {
                        HelpDrawerCoordinator.helpDrawerView(for: self) {
                            helpDrawerState.isShowingHashtagsHelpDrawer = false
                        }
                    }
                }
                .onAppear {
                    Analytics.shared.trackDidShowScreen(screenName: helpDrawerType.screenName)
                    HelpDrawerCoordinator.didShowHelp(for: helpDrawerType)
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
            HelpDrawerCoordinator.showFirstTimeHelp(for: helpDrawerType, state: helpDrawerState)
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
                HashtagListView(helpDrawerState: HelpDrawerState())
            }
            NavigationView {
                HashtagListView(helpDrawerState: HelpDrawerState())
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake)
    }
}
