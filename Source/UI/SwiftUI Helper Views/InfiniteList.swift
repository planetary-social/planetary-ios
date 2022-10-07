//
//  InfiniteList.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// https://swiftuirecipes.com/blog/infinite-scroll-list-in-swiftui
struct InfiniteList<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Hashable, Content: View {
    @Binding var data: Data
    @Binding var isLoading: Bool
    let loadMore: () -> Void
    let content: (Data.Element) -> Content
    
    init(
        data: Binding<Data>,
        isLoading: Binding<Bool>,
        loadMore: @escaping () -> Void,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        _data = data
        _isLoading = isLoading
        self.loadMore = loadMore
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(data, id: \.self) { item in
                    content(item)
                        .onAppear {
                            if item == data.last { 
                                loadMore()
                            }
                        }
                }
                if isLoading {
                    HStack {
                        
                    }.overlay(
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    )
                }
            }.onAppear(perform: loadMore)
        }
    }
}
