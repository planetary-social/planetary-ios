//
//  DatabaseFixtures.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/13/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

let testNetworkKey = NetworkKey(base64: "5vVhFHLFHeyutypUO952SyFd6jRIVhAyiZV30ftnKSU=")!

/// This struct contains information needed to construct a `ViewDatabase` for testing.
struct DatabaseFixture {

    let fileName: String
    let secret: Secret
    let network: NetworkKey
    let identities: [Identity]
    
    var owner: Identity {
        secret.identity
    }
    
    static let exampleFeed = DatabaseFixture(
        fileName: "Feed_example.json",
        secret: Secret(from: """
            {
              "curve": "ed25519",
              "public": "MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519",
              "private": "lnozk+qbbO86fv4SkclDqnRH4ilbStDjkr6ZZdVErAgyE6Qw/eMMKC5ttJWXlxWtmI8jdCh0I1eE6ew8DN1LAQ==.ed25519",
              "id": "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519"
            }
            """)!,
        network: testNetworkKey,
        identities: [
            "@gIBNiimNRlGPP0Ob2jV6cpiVukfbHoIvGlkYIidHpKY=.ed25519", // one
            "@3cEmxKx9ScNK8Pd1yz0qh5A2URzIbL7+VvpjfETU050=.ed25519", // userTwo
            "@TiCSZy2ICusS4RbL3H0I7tyrDFkucAVqTp6cjw2PETI=.ed25519", // three
            "@27PkouhQuhr9Ffn+rgSnN0zabcfoE31qD3ZMkCs3c+0=.ed25519", // userFour
            "@MhOkMP3jDCgubbSVl5cVrZiPI3QodCNXhOnsPAzdSwE=.ed25519" // privUser
        ]
    )
    
    static let bigFeed = DatabaseFixture(
        fileName: "Feed_big.json",
        secret: Secret(from: """
            {
                "id":"@GfNGDgRATmajkZlZ2xw5v5AY+LUkimtmL1hzdoxcnsQ=.ed25519",
                "private":"jqlylNN9AykX3dtFyMsa5GDov4L/1i8qPwolGcM77NoZ80YOBEBOZqORmVnbHDm/kBj4tSSKa2YvWHN2jFyexA==.ed25519",
                "curve":"ed25519",
                "public":"GfNGDgRATmajkZlZ2xw5v5AY+LUkimtmL1hzdoxcnsQ=.ed25519"
            }
            """)!,
        network: testNetworkKey,
        identities: [
            "@0uOwBrHIeiRK7lcvpLwjSFkcS3UHSQb/jyN52zf+J6Y=.ed25519", // Rabble
        ]
    )
}
