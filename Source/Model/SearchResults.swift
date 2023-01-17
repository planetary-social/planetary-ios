//
//  SearchResults.swift
//  Planetary
//
//  Created by Martin Dutra on 17/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model for all the different types of results that can be displayed.
struct SearchResults {
    enum ResultData {
        /// The search found people and posts.
        case universal(people: [About], posts: [Message])

        /// The search text was an identity.
        case feedID(FeedIdentifier)

        /// The search text was a message identifier.
        case messageID(Either<Message, MessageIdentifier>)

        /// The search is being performed.
        case loading

        /// The search has not being performed yet.
        case idle

        var isReadyToSearch: Bool {
            switch self {
            case .idle:
                return true
            default:
                return false
            }
        }
        var shouldShowLoading: Bool {
            switch self {
            case .idle, .loading:
                return true
            default:
                return false
            }
        }
    }

    var data: ResultData
    var query: String

    /// The sections that should be displayed for these results.
    var activeSections: [SearchResultsSection] {
        switch data {
        case .universal(let users, _):
            if users.isEmpty {
                return [.allResults]
            } else {
                return [.allResults, .people]
            }
        case .feedID:
            return [.allResults, .people]
        case .messageID:
            return [.allResults]
        case .loading, .idle:
            return [.allResults]
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
