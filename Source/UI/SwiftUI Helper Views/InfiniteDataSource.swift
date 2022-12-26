//
//  InfiniteDataSource.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol InfiniteDataSource: ObservableObject
where CachedCollection.Element: Hashable, CachedCollection.Element: Identifiable {
    associatedtype CachedCollection: RandomAccessCollection
    var cache: CachedCollection? { get }
    var errorMessage: String? { get set }

    /// If true, it is loading the first page
    var isLoadingFromScratch: Bool { get set }

    /// If true, it is loading more pages
    var isLoadingMore: Bool { get set }

    /// Loads the first page of messages
    ///
    /// It should set isLoadingFromScratch to true while loading and display an error if it fails.
    func loadFromScratch() async

    /// Loads another page of messages
    ///
    /// It should set isLoadingMore to true while loading.
    func loadMore() async
}
