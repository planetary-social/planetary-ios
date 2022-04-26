//
//  SecretTests.swift
//  FBTTUnitTests
//
//  Created by Christoph on 2/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import XCTest

class SecretTests: XCTestCase {

    // To avoid putting actual functioning keys into repo that can be
    // hacked, here are a couple of Base64 strings that can be used instead.
    // Note that they are used in the Secret.json resource file.

    // identity
    static let identity = "@VGhpcyBpcyB0b3RhbGx5IG5vdCBhbiBTU0IgaWRlbnRpdHkgcHVibGljIGtleQ==.ed25519"

    // "This is totally not an SSB identity public key"
    static let publicKey = "VGhpcyBpcyB0b3RhbGx5IG5vdCBhbiBTU0IgaWRlbnRpdHkgcHVibGljIGtleQ=="

    // "This is totally not an SSB identity private key"
    static let privateKey = "VGhpcyBpcyB0b3RhbGx5IG5vdCBhbiBTU0IgaWRlbnRpdHkgcHJpdmF0ZSBrZXk="

    func test_valid() {
        let data = self.data(for: "Secret.json")
        do {
            let secret = try JSONDecoder().decode(Secret.self, from: data)
            XCTAssertTrue(secret.curve == Algorithm.ed25519)
            XCTAssertTrue(secret.id.algorithm == Algorithm.ed25519)
            XCTAssertTrue(secret.id.id == SecretTests.publicKey)
            XCTAssertTrue(secret.id.sigil == Sigil.feed)
            XCTAssertTrue(secret.private.hasPrefix(SecretTests.privateKey))
            XCTAssertTrue(secret.public.hasPrefix(SecretTests.publicKey))
        } catch {
            XCTAssertNil(error)
        }
    }

    func test_encode() {
        let data = self.data(for: "Secret.json")
        guard let secret = try? JSONDecoder().decode(Secret.self, from: data) else { XCTFail(); return }
        do {
            _ = try JSONEncoder().encode(secret)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func test_invalid() {
        let data = self.data(for: "InvalidSecretMissingPrivate.json")
        do {
            _ = try JSONDecoder().decode(Secret.self, from: data)
            XCTFail("if this far, then Secret was decoded and should not be")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
