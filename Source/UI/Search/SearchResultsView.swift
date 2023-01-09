//
//  SearchResultsView.swift
//  Planetary
//
//  Created by Martin Dutra on 2/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI
import Logger

struct SearchResultsView: View {

    var searchText: String

    @State
    private var searchResults: SearchResults

    @State
    private var selectedSection: SearchResultsSection

    init(searchText: String) {
        self.searchText = searchText
        self.searchResults = SearchResults(data: .none, query: searchText)
        self.selectedSection = .all
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
                        case .all:
                            if searchResults.isEmpty {
                                EmptyHomeView()
                            } else {
                                SearchResultsGrid {
                                    ForEach(searchResults.posts) { message in
                                        MessageButton(message: message, type: .golden)
                                    }
                                    ForEach(searchResults.users, id: \.self) { identities in
                                        IdentityButton(identity: identities, type: .golden)
                                    }
                                }
                            }
                        case .people:
                            SearchResultsGrid {
                                ForEach(searchResults.users, id: \.self) { identities in
                                    IdentityButton(identity: identities, type: .golden)
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
            selectedSection = searchResults.activeSections.first ?? .all
        }
    }

    // MARK: - Loading Search Results

    private func fetchSearchResults(for query: String) async -> SearchResults {
        guard !query.isEmpty else {
            return SearchResults(data: .none, query: query)
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
            async let identities = loadIdentities(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResults(data: .universal(people: await identities, posts: await posts), query: query)
        }
    }

    func loadIdentities(matching filter: String) async -> [Identity] {
        do {
            return try await Bots.current.identities(matching: filter)
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
}

/// A model for all the different types of results that can be displayed.
fileprivate struct SearchResults {
    enum ResultData {
        case universal(people: [Identity], posts: [Message])
        case feedID(FeedIdentifier)
        case messageID(Either<Message, MessageIdentifier>)
        case loading
        case none
        var isReadyToSearch: Bool {
            switch self {
            case .none:
                return true
            default:
                return false
            }
        }
        var shouldShowLoading: Bool {
            switch self {
            case .none, .loading:
                return true
            default:
                return false
            }
        }
    }

    var data: ResultData
    var query: String

    /// The table view sections that should be displayed for these results.
    var activeSections: [SearchResultsSection] {
        switch data {
        case .universal(let users, _):
            if users.isEmpty {
                return [.all]
            } else {
                return [.all, .people]
            }
        case .feedID:
            return [.all, .people]
        case .messageID:
            return [.all]
        case .loading, .none:
            return [.all]
        }
    }

    var posts: [Message] {
        switch data {
        case .universal(_, let posts):
            return posts
        case .messageID(let result):
            switch result {
            case .left(let message):
                return [message]
            case .right:
                return []
            }
        default:
            return []
        }
    }

    var users: [FeedIdentifier] {
        switch data {
        case .feedID(let identity):
            return [identity]
        case .universal(let identities, _):
            return identities
        default:
            return []
        }
    }

    var isEmpty: Bool {
        posts.isEmpty && users.isEmpty
    }
}

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(searchText: "Hello")
    }
}
