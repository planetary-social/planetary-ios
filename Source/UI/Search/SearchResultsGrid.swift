//
//  SearchResultsGrid.swift
//  Planetary
//
//  Created by Martin Dutra on 6/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct SearchResultsGrid<Content>: View where Content: View {
    @ViewBuilder
    let content: Content

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            ZStack(alignment: .top) {
                LazyVGrid(columns: columns, spacing: 14) {
                    content
                }
                .frame(maxWidth: 500)
                .padding(10)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SearchResultsGrid_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsGrid {
            IdentityButton(identity: .null, style: .golden)
        }
        .background(Color.appBg)
        .injectAppEnvironment(botRepository: .fake, appController: .shared)
    }
}
