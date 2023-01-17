//
//  MessageDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol MessageDataSource: InfiniteDataSource {
    associatedtype CachedCollection = [Message]
}
