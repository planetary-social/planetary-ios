//
//  LogsBuilderMock.swift
//  
//
//  Created by Martin Dutra on 28/6/22.
//

@testable import CrashReporting
import Foundation
import Logger

class LogsBuilderMock: LogsBuilder {
    var appLog: String?
    var botLog: String?

    func build(logger: LogProtocol, identity: Identity?) -> Logs {
        Logs(appLog: appLog, botLog: botLog)
    }
}
