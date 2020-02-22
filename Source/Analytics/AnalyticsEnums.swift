//
//  AnalyticsEnums.swift
//  FBTT
//
//  Created by Christoph on 5/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct AnalyticsEnums {

    enum Event: String, CaseIterable {
        case did
        case load
        case log
        case publish
        case purge
        case tap
        case time
        case view
    }

    enum Element: String, CaseIterable {
        case api
        case app
        case blob
        case bot
        case button
        case cache
        case os         // OS = operating system
        case screen
    }

    enum Name: String, CaseIterable {

        enum API: String, CaseIterable {
            case pub
            case verse
        }

        case background
        case backgroundSync = "background_sync"

        enum Cache: String, CaseIterable {
            case blob
            case text
            case truncatedText
        }

        case exit

        case foreground

        case launch
        
        case loadBlob = "load_blob"

        enum Log: String, CaseIterable {
            case error
            case fatal
            case info
            case unexpected
        }

        case notification
        
        case offboarding
        case onboarding

        case publishBlob = "publish_blob"

        case refresh

        case repair

        case settings

        case sync

        // compiler seems to want this, must be related
        // to a nested enum having an associated value
        typealias RawValue = String
        case requiredCaseForRawValue
    }

    typealias Params = [String: Any]
}
