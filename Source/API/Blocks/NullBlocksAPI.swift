//
//  NullBlocksAPI.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

class NullBlockedAPI: BlockedAPIService {

    func retreiveBlockedList(completion: @escaping BlockedListCompletion) {
        completion([], nil)
    }
}
