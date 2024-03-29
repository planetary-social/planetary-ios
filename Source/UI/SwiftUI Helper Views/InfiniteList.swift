//
//  InfiniteList.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// https://swiftuirecipes.com/blog/infinite-scroll-list-in-swiftui
struct InfiniteList<DataSource, Content>: View where DataSource: InfiniteDataSource, Content: View {

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
                    InfiniteStack(dataSource: dataSource, content: content)
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
