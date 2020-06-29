//
//  BlocksAPIService.swift
//  Planetary
//
//  Created by H on 19.06.20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias BlockedListCompletion = (([String], APIError?) -> Void)

protocol BlockedAPIService {

    // retreives the full list, no pagination
    func retreiveBlockedList(completion: @escaping BlockedListCompletion)
}
