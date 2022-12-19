//
//  InfiniteStackView.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct InfiniteStackView<DataSource, Content>: View where DataSource: InfiniteList, Content: View {

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
            if let cache = dataSource.cache {
                ZStack {
                    LazyVStack(alignment: .center) {
                        if cache.isEmpty {
                            EmptyHomeView()
                        } else {
                            ForEach(cache, id: \.self) { item in
                                content(item)
                                    .onAppear {
                                        if item == cache.last {
                                            dataSource.loadMore()
                                        }
                                    }
                            }
                            if dataSource.isLoadingMore {
                                HStack {
                                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 500)
                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                }
            }
        }
        .task {
            if dataSource.cache == nil, !dataSource.isLoadingFromScratch {
                await dataSource.loadFromScratch()
            }
        }
    }
}
