//
//  MessageList.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol MessageList: InfiniteList {
    associatedtype CachedCollection = [Message]
    var cache: [Message]? { get }
    var isLoadingFromScratch: Bool { get set }
    var isLoadingMore: Bool { get set }
    func loadFromScratch() async
    func loadMore()
}
