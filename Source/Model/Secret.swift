//
//  Secret.swift
//  FBTT
//
//  Created by Christoph on 2/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Secret: Codable {

    let curve: Algorithm
    let id: Identity
    let `private`: String
    let `public`: String

    init?(from string: String) {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let secret = try? JSONDecoder().decode(Secret.self, from: data) else { return nil }
        self = secret
    }

    func jsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        let string = String(data: data, encoding: .utf8)
        return string
    }

    func jsonStringUnescaped() -> String? {
        guard let string = self.jsonString() else { return nil }
        let unescaped = string.replacingOccurrences(of: "\\/", with: "/", options: .literal, range: nil)
        return unescaped
    }
}

extension Secret {
    var identity: Identity { self.id }
}

extension Secret: Equatable {
    public static func == (lhs: Secret, rhs: Secret) -> Bool {
        lhs.id == rhs.id
    }
}
