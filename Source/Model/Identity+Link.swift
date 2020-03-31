//
//  Identity+Link.swift
//  Planetary
//
//  Created by Martin Dutra on 3/30/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Identity {

    var publicLink: URL? {
        let base64Identifier = Data(self.utf8).base64EncodedString()
        return URL(string: "https://planetary.social/p/\(base64Identifier)")
    }

    static func parse(publicLink: URL) -> Identity? {
        let components = publicLink.pathComponents
        if components.count >= 3, components[1] == "p" {
            let base64Identifier = components[2]
            guard let data = Data(base64Encoded: base64Identifier) else {
                return nil
            }
            return Identity(data: data, encoding: .utf8)
        } else {
            return nil
        }
    }

}
