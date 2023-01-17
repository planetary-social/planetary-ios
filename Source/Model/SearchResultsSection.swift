//
//  SearchResultsSection.swift
//  Planetary
//
//  Created by Martin Dutra on 6/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A model for all the different types of sections that can be displayed when searching.
enum SearchResultsSection: Int, CaseIterable, Identifiable {
    /// Shows all elements the search found (posts, people, etc).
    case allResults

    /// Shows only identities.
    case people

    var id: Int {
        rawValue
    }
    
    var label: some View {
        Group {
            switch self {
            case .allResults:
                Text(Localized.Search.all.text)
            case .people:
                Text(Localized.Search.people.text)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 12, bottom: 5, trailing: 14))
    }
}
