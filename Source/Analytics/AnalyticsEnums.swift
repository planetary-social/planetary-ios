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
        case tap
        case time
        case view
        case select
        case show
        
        case publish
    }

    enum Element: String, CaseIterable {
        case api
        case app
        case bot
        case button
        case screen
        case tab
        case action
        case searchBar = "search_bar"
        case item
        
        case profile
        case identity
        case post
    }

    enum Name: String, CaseIterable {

        enum API: String, CaseIterable {
            case pub
            case verse
        }

        case background

        enum Cache: String, CaseIterable {
            case blob
            case text
            case truncatedText
        }

        case exit
        
        case backgroundFetch = "background_fetch"
        
        case backgroundTask = "background_task"

        case foreground

        case launch

        enum Log: String, CaseIterable {
            case error
            case fatal
            case info
            case unexpected
        }

        case receive_remote_notification = "receive_remote_notification"
        
        case notification
        
        case offboarding
        case onboarding

        case refresh

        case repair
        case db_update
        
        case settings

        case sync
        
        //case db

        // compiler seems to want this, must be related
        // to a nested enum having an associated value
        typealias RawValue = String
        case requiredCaseForRawValue
    }

    typealias Params = [String: Any]
}
