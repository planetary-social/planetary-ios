//
//  SearchResultsView.swift
//  Planetary
//
//  Created by Martin Dutra on 2/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import SwiftUI
import Logger

/// This view is displayed when the user is doing an universal search.
///
/// It displays a feed of messages or identities in a sectioned grid.
struct SearchResultsView: View {

    var searchText: String

    @EnvironmentObject
    private var botRepository: BotRepository
    
    @State
    private var searchResults: SearchResults

    @State
    private var selectedSection: SearchResultsSection

    init(searchText: String) {
        self.searchText = searchText
        self.searchResults = SearchResults(data: .idle, query: searchText)
        self.selectedSection = .allResults
    }

    var body: some View {
        Group {
            if searchResults.data.shouldShowLoading {
                LoadingView()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    SearchResultsTab(sections: searchResults.activeSections, selectedSection: $selectedSection)
                    Group {
                        switch selectedSection {
                        case .allResults:
                            if searchResults.isEmpty {
                                EmptyPostsView(title: Localized.noResultsFound, description: Localized.noResultsHelp)
                            } else {
                                SearchResultsGrid {
                                    ForEach(searchResults.posts) { message in
                                        MessageButton(message: message, style: .golden)
                                    }
                                    ForEach(searchResults.users) { identityOrAbout in
                                        switch identityOrAbout {
                                        case .left(let identity):
                                            IdentityButton(identity: identity, style: .golden)
                                        case .right(let about):
                                            IdentityButton(identity: about.identity, style: .golden)
                                        }
                                    }
                                }
                            }
                        case .people:
                            SearchResultsGrid {
                                ForEach(searchResults.users) { identityOrAbout in
                                    switch identityOrAbout {
                                    case .left(let identity):
                                        IdentityButton(identity: identity, style: .golden)
                                    case .right(let about):
                                        IdentityButton(identity: about.identity, style: .golden)
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .task(id: searchText) {
            guard searchResults.data.isReadyToSearch || searchResults.query != searchText else {
                return
            }
            searchResults = SearchResults(data: .loading, query: searchText)
            searchResults = await fetchSearchResults(for: searchText)
            selectedSection = searchResults.activeSections.first ?? .allResults
        }
    }

    // MARK: - Loading Search Results

    private func fetchSearchResults(for query: String) async -> SearchResults {
        guard !query.isEmpty else {
            return SearchResults(data: .idle, query: query)
        }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier: Identifier = query
        let isFeedIdentifier = identifier.isValidIdentifier && identifier.sigil == .feed
        let isMessageIdentifier = identifier.isValidIdentifier && identifier.sigil == .message

        if isFeedIdentifier {
            return SearchResults(data: .feedID(identifier), query: query)
        } else if isMessageIdentifier {
            return SearchResults(data: .messageID(await loadMessage(with: identifier)), query: query)
        } else {
            async let abouts = loadAbouts(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResults(data: .universal(people: await abouts, posts: await posts), query: query)
        }
    }

    func loadAbouts(matching filter: String) async -> [About] {
        let bot = botRepository.current
        do {
            return try await bot.abouts(matching: filter)
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return []
        }
    }

    func loadPosts(matching filter: String) async -> [Message] {
        let bot = botRepository.current
        do {
            return try await bot.posts(matching: filter)
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
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
}

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(searchText: "Hello")
            .injectAppEnvironment(botRepository: .fake, appController: .shared)
    }
}
