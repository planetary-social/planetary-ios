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
        return URL(string: "https://planetary.social/p/\(self)")
    }

    static func parse(publicLink: URL) -> Identity? {
        let path = publicLink.path
        let components = publicLink.pathComponents
        if components.count >= 2, components[1] == "p" {
            let identifier = Identifier(path.dropFirst(3))
            if identifier.isValidIdentifier {
                return identifier
            }
            return nil
        } else {
            return nil
        }
    }

}
