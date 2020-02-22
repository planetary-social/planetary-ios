//
//  VerseAPI+Me.swift
//  FBTT
//
//  Created by Christoph on 8/9/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension VerseAPI {

    struct Me {

        func isInDirectory(completion: @escaping ((Bool, APIError?) -> Void)) {
            VerseAPI.me() {
                me, error in
                let inDirectory = me?.in_directory ?? false
                completion(inDirectory, error)
            }
        }

        func showInDirectory(_ show: Bool,
                             completion: @escaping ((Bool, APIError?) -> Void))
        {
            guard let identity = Bots.current.identity else { completion(false, .invalidIdentity); return }
            if show { VerseAPI.directory(show: identity, completion: completion) }
            else    { VerseAPI.directory(hide: identity, completion: completion) }
        }
    }

    static let me = Me()

    static func me(completion: @escaping ((Person?, APIError?) -> Void)) {
        guard let identity = Bots.current.identity else { completion(nil, .invalidIdentity); return }
        let headers: APIHeaders = ["X-Identity": identity]
        VerseAPI.api.get(path: "/mainnet-directory/me", query: [], headers: headers) {
            me, error in
            completion(me?.person(), error)
        }
    }
}
