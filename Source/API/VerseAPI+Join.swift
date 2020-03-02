//
//  VerseAPI+Join.swift
//  FBTT
//
//  Created by Christoph on 6/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension VerseAPI {

    // TODO joining with an existing phone number returns the Person
    // with that number, not a new record
    static func join(identity: Identity,
                     name: String,
                     birthdate: Date,
                     phone: String,
                     completion: @escaping ((Person?, APIError?) -> Void))
    {
        let json: [String: Any] =
            ["birthday": birthdate,
             "identity": identity,
             "phonenumber": phone,
             "name": name,
             "using_plural": true,
             "verified_phone": true]
        self.api.post(path: "/\(Environment.Verse.directoryPath)/people", json: json) {
            data, error in
            completion(data?.person(), error)
        }
    }

    // TODO quit verse
    static func quit() {}
}
