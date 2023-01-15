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
            async let abouts = loadAbouts(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResults(data: .universal(people: await abouts, posts: await posts), query: query)
        }
    }

    func loadAbouts(matching filter: String) async -> [About] {
        do {
            return try await Bots.current.abouts(matching: filter)
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return []
        }
    }

    func loadPosts(matching filter: String) async -> [Message] {
        do {
            return try await Bots.current.posts(matching: filter)
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

/// A model for all the different types of results that can be displayed.
fileprivate struct SearchResults {
    enum ResultData {
        case universal(people: [About], posts: [Message])
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

    var users: [Either<FeedIdentifier, About>] {
        switch data {
        case .feedID(let identity):
            return [.left(identity)]
        case .universal(let abouts, _):
            return abouts.map { Either<FeedIdentifier, About>.right($0) }
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

extension Either: Identifiable, Equatable, Hashable where Left == FeedIdentifier, Right == About {
    var id: Identity {
        switch self {
        case .left(let identity):
            return identity
        case .right(let about):
            return about.identity
        }
    }
    static func == (lhs: Either, rhs: Either) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
