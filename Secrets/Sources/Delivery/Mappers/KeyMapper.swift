//
//  KeyMapper.swift
//  
//
//  Created by Martin Dutra on 8/12/21.
//

import Foundation

class KeyMapper {
    func map(key: Secrets.Key) -> Key? {
        switch key {
        case .posthog:
            return Key.posthog
        case .bugsnag:
            return Key.bugsnag
        case .push:
            return Key.push
        }
    }
}
