//
//  InfiniteList.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol InfiniteList: ObservableObject where CachedCollection.Element: Hashable, CachedCollection.Element: Identifiable {
    associatedtype CachedCollection: RandomAccessCollection
    var cache: CachedCollection { get }
    var isLoading: Bool { get set }
    func loadMore()
}

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
//        ScrollView {
        if #available(iOS 16.0, *) {
            List {
                ForEach(dataSource.cache, id: \.self) { item in
                    content(item)
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 10))
                        .listRowSeparator(.hidden)
                        .onAppear {
                            if item == dataSource.cache.last {
                                dataSource.loadMore()
                            }
                        }
                }
                if dataSource.isLoading {
                    HStack {}
                        .listRowSeparator(.hidden)
                        .overlay(
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        )
                }
            }
            .onAppear(perform: dataSource.loadMore)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#1f172f"))
        } else {
            EmptyView()
            // Fallback on earlier versions
        }
//        }
    }
}
