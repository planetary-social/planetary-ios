//
//  SearchResultsSection.swift
//  Planetary
//
//  Created by Martin Dutra on 6/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

enum SearchResultsSection: Int, CaseIterable, Identifiable {
    case all, people
    var id: Int {
        rawValue
    }
    var label: some View {
        Group {
            switch self {
            case .all:
                Text(Localized.Search.all.text)
            case .people:
                Text(Localized.Search.people.text)
            }
        }
        .padding(EdgeInsets(top: 6, leading: 12, bottom: 5, trailing: 14))
    }
}

struct SearchResultsSection_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            ForEach(SearchResultsSection.allCases) { section in
                section.label
            }
        }
        .background(Color.appBg)
    }
}
