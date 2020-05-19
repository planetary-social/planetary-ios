//
//  DirectoryAPI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/18/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct DirectoryAPI {
    
    static var shared: DirectoryAPIService = {
        // We don't want to spam the push API when running tests
        #if UNIT_TESTS
        return NullDirectoryAPI()
        #else
        if CommandLine.arguments.contains("mock-directory-api") {
            return NullDirectoryAPI()
        } else {
            return VerseDirectoryAPI()
        }
        #endif
    }()
    
}
