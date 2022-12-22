//
//  InfiniteList.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol InfiniteList: ObservableObject
where CachedCollection.Element: Hashable, CachedCollection.Element: Identifiable {
    associatedtype CachedCollection: RandomAccessCollection
    var cache: CachedCollection? { get }
    var errorMessage: String? { get set }
    var isLoadingFromScratch: Bool { get set }
    var isLoadingMore: Bool { get set }
    func loadFromScratch() async
    func loadMore()
}
