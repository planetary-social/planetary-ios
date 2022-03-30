//
//  FileLoggerServiceMock.swift
//  
//
//  Created by Martin Dutra on 22/11/21.
//

import Foundation
@testable import Logger

class FileLoggerServiceMock: FileLoggerService {

    var invokedDebug = false
    var invokedInfo = false
    var invokedError = false
    var lastLine: String = ""

    var fileUrls: [URL] {
        []
    }

    func debug(_ string: String) {
        invokedDebug = true
        lastLine = string
    }

    func info(_ string: String) {
        invokedInfo = true
        lastLine = string
    }

    func error(_ string: String) {
        invokedError = true
        lastLine = string
    }
}
