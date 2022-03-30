//
//  UserDefaults+Debug.swift
//  FBTT
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import Foundation

// TODO https://app.asana.com/0/914798787098068/1122607002060947/f
// TODO deprecate identity manager
extension UserDefaults {

    #if DEBUG
        var secret: Secret? {
            get {
                guard let data = self.data(forKey: #function) else {
                    return nil
                }
                return try? JSONDecoder().decode(Secret.self, from: data)
            }
            set {
                let data = try? JSONEncoder().encode(newValue)
                self.setValue(data, forKey: #function)
            }
        }
    #else
        var secret: Secret? {
            get { nil }
            set {}
        }
    #endif

    #if DEBUG
        var networkKey: NetworkKey? {
            get {
                guard let data = (self.value(forKey: #function) as? Data) else {
                    return NetworkKey.ssb
                }
                return NetworkKey(base64: data)
            }
            set {
                guard let root = newValue else {
                    return
                }
                self.set(root.data, forKey: #function)
            }
        }
    #else
        var networkKey: NetworkKey? {
            get { NetworkKey.ssb }
            set {}
        }
    #endif
}

extension UserDefaults {

    // example of "write on read" where reading will reset
    // the value, allowing this to only return true once
    // the first call to UserDefaults.forceOnboarding
    var simulateOnboarding: Bool {
        get {
            let flag = self.bool(forKey: #function)
            self.set(false, forKey: #function)
            return flag
        }
        set {
            self.set(newValue, forKey: #function)
        }
    }
}

extension UserDefaults {

    var showPeerToPeerWidget: Bool {
        get {
            true
            // for now this is always turned on
//            return self.bool(forKey: #function)
        }
        set {
            self.set(newValue, forKey: #function)
        }
    }
}
