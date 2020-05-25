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
        return URL(string: "https://planetary.link/\(self)")
    }

    static func parse(publicLink: URL) -> Identifier? {
        let identifier = Identifier(publicLink.path.dropFirst())
        if identifier.isValidIdentifier {
            return identifier
        }
        return nil
    }

}
