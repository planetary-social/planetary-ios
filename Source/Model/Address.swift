//
//  Address.swift
//  FBTT
//
//  Created by Henry Bubert on 02.04.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// new pub/peer advertisments
// address is multiserver encoded like net:10.10.0.1:8008~shs:pybKey=
// but only go bot has to deal with that.
// just using sqlite the datastore for enable/worked
struct Address: Codable {
    let type: ContentType
    let address: String
    let availability: Double
}


struct Pub: Codable {
    let type: ContentType
    let address: PubAddress
}

struct PubAddress: Codable {
    let key: Identifier
    let host: String
    let port: UInt
}
