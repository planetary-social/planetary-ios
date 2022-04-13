//
//  UserDefaults+Debug.swift
//  FBTT
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import Foundation

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
