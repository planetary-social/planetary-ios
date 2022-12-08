//
//  Identity+Link.swift
//  Planetary
//
//  Created by Martin Dutra on 3/30/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

extension Identity {
    
    var publicLink: URL? {
        let host = "https://planetary.link/"
        let msgPath = self.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!
        return URL(string: host + msgPath)
    }

    var deepLink: URL? {
        let host = "planetary://planetary/"
        let msgPath = self.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!
        return URL(string: host + msgPath)
    }

    static func parse(publicLink: URL) -> Identifier? {
        guard publicLink.host == "planetary.link" else {
            return nil
        }

        let oldIdentifier = Identifier(publicLink.path.dropFirst())
        if oldIdentifier.isValidIdentifier {
            return oldIdentifier
        }
        
        let identifier = Identifier(publicLink.path)
        if identifier.isValidIdentifier {
            return identifier
        }
        
        return nil
    }
}
