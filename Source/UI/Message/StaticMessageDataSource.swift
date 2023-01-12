//
//  StaticMessageDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 26/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

class StaticMessageDataSource: MessageDataSource {

    init(messages: [Message]) {
        cache = messages
    }

    var cache: [Message]?

    var errorMessage: String?

    var isLoadingFromScratch = false

    var isLoadingMore = false

    func loadFromScratch() async { }

    func loadMore() async { }
}
