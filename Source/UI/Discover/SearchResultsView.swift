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

    /// A model for all the different types of results that can be displayed.
    struct SearchResults {
        enum ResultData {
            case universal(people: [About], posts: [Message])
            case feedID(Either<About, FeedIdentifier>)
            case messageID(Either<Message, MessageIdentifier>)
            case loading
            case none
        }

        var data: ResultData
        var query: String

        /// The table view sections that should be displayed for these results.
        var activeSections: [Section] {
            switch data {
            case .universal:
                return [.network, .posts]
            case .feedID(let result):
                switch result {
                case .left:
                    return [.network]
                case .right:
                    return [.users]
                }
            case .messageID:
                return [.posts]
            case .loading, .none:
                return []
            }
        }

        var posts: [Message]? {
            switch data {
            case .universal(_, let posts):
                return posts
            case .messageID(let result):
                switch result {
                case .left(let message):
                    return [message]
                case .right:
                    return nil
                }
            default:
                return nil
            }
        }

        var inNetworkPeople: [About]? {
            switch data {
            case .universal(let people, _):
                return people
            case .feedID(let result):
                switch result {
                case .left(let about):
                    return [about]
                case .right:
                    return nil
                }
            default:
                return nil
            }
        }

        var user: FeedIdentifier? {
            switch data {
            case .feedID(let result):
                switch result {
                case .left:
                    return nil
                case .right(let identifier):
                    return identifier
                }
            default:
                return nil
            }
        }

        var postCount: Int {
            posts?.count ?? 0
        }

        var inNetworkPeopleCount: Int {
            inNetworkPeople?.count ?? 0
        }
    }

    /// A model for the various table view sections
    enum Section: Int, CaseIterable, Identifiable {
        case users, posts, network
        var id: Int {
            rawValue
        }
    }
    
    var searchResults: SearchResults

    init(searchResults: SearchResults) {
        self.searchResults = searchResults
        self.selectedSection = searchResults.activeSections.first
    }
    
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    func tab(content: () -> some View) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                LazyVGrid(columns: columns, spacing: 14) {
                    content()
                }
                .frame(maxWidth: 500)
                .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
            }
            .frame(maxWidth: .infinity)
        }
    }

    @State
    private var selectedSection: Section?

    func tabLabel(for section: Section) -> some View {
        Group {
            switch section {
            case .users:
                Text(Localized.users.text)
            case .posts:
                Text(Localized.posts.text)
            case .network:
                Text(Localized.inYourNetwork.text)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 12, bottom: 5, trailing: 14))
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                ForEach(searchResults.activeSections) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        if selectedSection == section {
                            tabLabel(for: section)
                                .foregroundColor(.white)
                                .background(Color(hex: "1A1129"))
                                .cornerRadius(20)
                        } else {
                            tabLabel(for: section)
                                .foregroundColor(.secondaryTxt)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2A1C45"), Color(hex: "231638")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            if let selectedSection = selectedSection {
                switch selectedSection {
                case .users:
                    if let identity = searchResults.user {
                        tab {
                            IdentityButton(identity: identity)
                        }
                    } else {
                        EmptyView()
                    }
                case .posts:
                    if let posts = searchResults.posts {
                        tab {
                            ForEach(posts) { message in
                                MessageButton(message: message, type: .golden)
                            }
                        }
                    } else {
                        EmptyView()
                    }
                case .network:
                    if let network = searchResults.inNetworkPeople {
                        tab {
                            ForEach(network) { about in
                                IdentityButton(identity: about.identity)
                            }
                        }
                    } else {
                        EmptyView()
                    }
                }
            } else {
                EmptyView()
            }
            Spacer()
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
            return SearchResults(data: .feedID(await loadPerson(with: identifier)), query: query)
        } else if isMessageIdentifier {
            return SearchResults(data: .messageID(await loadMessage(with: identifier)), query: query)
        } else {
            async let people = loadPeople(matching: normalizedQuery)
            async let posts = loadPosts(matching: normalizedQuery)
            return SearchResults(data: .universal(people: await people, posts: await posts), query: query)
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

struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(
            searchResults: SearchResultsView.SearchResults(data: .feedID(.right(.null)), query: "")
        )
    }
}
