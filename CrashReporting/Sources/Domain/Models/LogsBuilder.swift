//
//  LogsBuilder.swift
//  
//
//  Created by Martin Dutra on 28/6/22.
//

import Foundation
import Logger

protocol LogsBuilder {
    func build(logger: LogProtocol, identity: Identity?) -> Logs
}
