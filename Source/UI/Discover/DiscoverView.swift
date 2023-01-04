//
//  DiscoverView.swift
//  Planetary
//
//  Created by Martin Dutra on 27/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct DiscoverView: View, HelpDrawerHost {

    init(helpDrawerState: HelpDrawerState, bot: Bot) {
        self.helpDrawerState = helpDrawerState
        self.dataSource = FeedStrategyMessageDataSource(strategy: DiscoverStrategy(), bot: bot)
    }

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    @ObservedObject
    private var helpDrawerState: HelpDrawerState

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    @State
    private var searchText = ""

    @SwiftUI.Environment(\.isSearching)
    private var isSearching

    @State
    private var searchResults: SearchResultsView.SearchResults?

    let helpDrawerType = HelpDrawer.discover

    func dismissDrawer(completion: (() -> Void)?) {
        helpDrawerState.isShowingHomeHelpDrawer = false
        // Unfortunately, there is no good way to know when the popover dismissed in SwiftUI
        // So here I use a nasty simple trick to let the completion open the next drawer.
        // Fortunately, we can get rid of this after we migrate the remaining screens to SwiftUI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            completion?()
        }
    }

    @SwiftUI.Environment(\.horizontalSizeClass)
    var horizontalSizeClass

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    var body: some View {
        ZStack(alignment: .top) {
            if let searchResults = searchResults {
                SearchResultsView(searchResults: searchResults)
            } else {
                MessageGrid(dataSource: dataSource)
                    .placeholder(when: dataSource.isEmpty) {
                        EmptyDiscoverView()
                    }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: (.always)))
        .disableAutocorrection(true)
        .onChange(of: searchText) { value in
            if value.isEmpty && !isSearching {
                Task {
                    await filter()
                }
            }
        }
        .onSubmit(of: .search) {
            Task {
                await filter()
            }
        }
        .background(Color.appBg)
        .navigationTitle(Localized.explore.text)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    helpDrawerState.isShowingDiscoverHelpDrawer = true
                } label: {
                    Image.navIconHelp
                }
                .popover(isPresented: $helpDrawerState.isShowingDiscoverHelpDrawer) {
                    Group {
                        if #available(iOS 16.0, *) {
                            HelpDrawerCoordinator.helpDrawerView(for: self) {
                                helpDrawerState.isShowingDiscoverHelpDrawer = false
                            }
                            .presentationDetents([.medium])
                        } else {
                            HelpDrawerCoordinator.helpDrawerView(for: self) {
                                helpDrawerState.isShowingDiscoverHelpDrawer = false
                            }
                        }
                    }
                    .onAppear {
                        Analytics.shared.trackDidShowScreen(screenName: helpDrawerType.screenName)
                        HelpDrawerCoordinator.didShowHelp(for: helpDrawerType)
                    }
                }
                Button {
                    Analytics.shared.trackDidTapButton(buttonName: "compose")
                    showCompose()
                } label: {
                    Image.navIconWrite
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didChangeDiscoverFeedAlgorithm)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didUpdateRelationship)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didPublishPost)) { _ in
            Task {
                await dataSource.loadFromScratch()
            }
        }
        .onAppear {
            CrashReporting.shared.record("Did Show Discover")
            Analytics.shared.trackDidShowScreen(screenName: "discover")
            HelpDrawerCoordinator.showFirstTimeHelp(for: helpDrawerType, state: helpDrawerState)
        }
    }

    private func showCompose() {
        let controller = NewPostViewController()
        controller.didPublish = { post in
            NotificationCenter.default.post(.didPublishPost(post))
        }
        let navController = UINavigationController(rootViewController: controller)
        appController.present(navController, animated: true)
    }

    private func filter() async {
        searchResults = await fetchSearchResults(for: searchText)
    }

    private func fetchSearchResults(for query: String) async -> SearchResultsView.SearchResults? {
        guard !query.isEmpty else {
            return nil
        }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: Identifier = query
        let isFeedIdentifier = identifier.isValidIdentifier && identifier.sigil == .feed
        let isMessageIdentifier = identifier.isValidIdentifier && identifier.sigil == .message

        if isFeedIdentifier {
            return SearchResultsView.SearchResults(data: .feedID(await loadPerson(with: identifier)), query: query)
        } else if isMessageIdentifier {
            return SearchResultsView.SearchResults(data: .messageID(await loadMessage(with: identifier)), query: query)
        } else {
            async let people = loadPeople(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResultsView.SearchResults(data: .universal(people: await people, posts: await posts), query: query)
        }
    }

    func loadPeople(matching filter: String) async -> [About] {
        do {
            return try await Bots.current.abouts(matching: filter)
        } catch {
            Log.optional(error)
            return []
        }
    }

    func loadPosts(matching filter: String) async -> [Message] {
        do {
            return try await Bots.current.posts(matching: filter)
        } catch {
            Log.optional(error)
            return []
        }
    }

    /// Loads the message with the given id from the database and displays it if it's still valid.
    func loadMessage(with msgID: MessageIdentifier) async -> Either<Message, MessageIdentifier> {
        var result: Either<Message, MessageIdentifier>
        do {
            result = .left(try Bots.current.post(from: msgID))
        } catch {
            result = .right(msgID)
            Log.optional(error)
        }
        return result
    }

    func loadPerson(with feedIdentifier: FeedIdentifier) async -> Either<About, FeedIdentifier> {
        var result: Either<About, FeedIdentifier>
        do {
            let about = try await Bots.current.about(identity: feedIdentifier)
            if let about = about {
                result = .left(about)
            } else {
                result = .right(feedIdentifier)
            }
        } catch {
            result = .right(feedIdentifier)
            Log.optional(error)
        }
        return result
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                DiscoverView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            NavigationView {
                DiscoverView(helpDrawerState: HelpDrawerState(), bot: FakeBot.shared)
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake)
    }
}
