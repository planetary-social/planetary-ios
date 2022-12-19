//
//  InfiniteList.swift
//  Planetary
//
//  Created by Martin Dutra on 18/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol InfiniteList: ObservableObject where CachedCollection.Element: Hashable, CachedCollection.Element: Identifiable {
    associatedtype CachedCollection: RandomAccessCollection
    var cache: CachedCollection? { get }
    var isLoadingFromScratch: Bool { get set }
    var isLoadingMore: Bool { get set }
    func loadFromScratch() async
    func loadMore()
}
