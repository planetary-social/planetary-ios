//
//  Keychain.swift
//  FBTT
//
//  Created by Christoph on 5/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import KeychainSwift

/// This class is provided as a wrapper over the chosen Keychain
/// framework.  This is simply to insulate the app code from any
/// unforeseen changes in Keychain frameworks, plus allow hooking
/// in iCloud or other secure storage mechanisms.
///
/// Note that all value are written with `accessibleAfterFirstUnlock` to allow
/// use while the app is in the background i.e. for background syncs for notifications.
/// https://developer.apple.com/documentation/security/ksecattraccessibleafterfirstunlock
class Keychain {

    private static let keychain = KeychainSwift()

    static func string(for key: String) -> String? {
        self.keychain.get(key)
    }

    static func bool(for key: String) -> Bool? {
        self.keychain.getBool(key)
    }

    static func data(for key: String) -> Data? {
        self.keychain.getData(key)
    }

    static func set(_ value: String, for key: String) {
        self.keychain.set(value, forKey: key, withAccess: .accessibleAfterFirstUnlock)
    }

    static func set(_ value: Bool, for key: String) {
        self.keychain.set(value, forKey: key, withAccess: .accessibleAfterFirstUnlock)
    }

    static func set(_ value: Data, for key: String) {
        self.keychain.set(value, forKey: key, withAccess: .accessibleAfterFirstUnlock)
    }

    static func delete(_ key: String) {
        self.keychain.delete(key)
    }

    static func clear() {
        self.keychain.clear()
    }
}
