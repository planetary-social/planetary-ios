//
//  InfiniteListView.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// https://swiftuirecipes.com/blog/infinite-scroll-list-in-swiftui
struct InfiniteListView<DataSource, Content>: View where DataSource: InfiniteList, Content: View {

    @ObservedObject var dataSource: DataSource
    let content: (DataSource.CachedCollection.Element) -> Content

    init(
        dataSource: DataSource,
        @ViewBuilder content: @escaping (DataSource.CachedCollection.Element) -> Content
    ) {
        self.dataSource = dataSource
        self.content = content
    }

    var body: some View {
        Group {
            if dataSource.cache != nil {
                ScrollView(.vertical, showsIndicators: false) {
                    InfiniteStackView(dataSource: dataSource, content: content)
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if dataSource.cache == nil {
                await dataSource.loadFromScratch()
            }
        }
        .refreshable {
            await dataSource.loadFromScratch()
        }
    }
}
