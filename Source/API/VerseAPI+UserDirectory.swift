//
//  VerseAPI+UserDirectory.swift
//  FBTT
//
//  Created by Christoph on 6/14/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension VerseAPI {

    // TODO https://app.asana.com/0/914798787098068/1153089238227798/f
    // TODO need directory endpoint to return a Person for an Identity
    // TODO https://app.asana.com/0/914798787098068/1135074810262437/f
    // TODO intelligent pagination required
    static func directory(includeMe: Bool = true, completion: @escaping (([Person], APIError?) -> Void)) {
        //Todo: we'll need to change this to do pagination before we get 1000 users
        let per_page = URLQueryItem(name: "per_page", value: "1000")
        self.api.get(path: "/\(Environment.Verse.directoryPath)/", query: [per_page]) {
            data, error in
            var people = data?.persons() ?? []
            people = people.filter { $0.name.isValidName }
            if !includeMe {
                let me = Bots.current.identity
                people = people.filter { $0.identity != me }
            }
            completion(people, error)
        }
    }

    static func directory(show identity: Identity,
                          completion: @escaping ((Bool, APIError?) -> Void))
    {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(Environment.Verse.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": true]

        self.api.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }

    static func directory(hide identity: Identity,
                          completion: @escaping ((Bool, APIError?) -> Void))
    {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(Environment.Verse.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": false]

        self.api.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }

    static func directory(offboard identity: Identity,
                          completion: @escaping ((Bool, APIError?) -> Void))
    {
        // TODO https://app.asana.com/0/1109616169284147/1135482214678101/f
        // TODO ticket for parameter name casing
        let path = "/\(Environment.Verse.directoryPath)/people/"
        let json: [String: Any] = ["Identity": identity,
                                   "in_directory": false,
                                   "offboarded": true]

        self.api.post(path: path, json: json) {
            _, error in
            completion(error == nil, error)
        }
    }
}
