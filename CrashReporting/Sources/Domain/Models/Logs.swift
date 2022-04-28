//
//  Logs.swift
//  
//
//  Created by Martin Dutra on 28/4/22.
//

import Foundation

/// Stores the contents of the logs files to attach as metadata to all events
struct Logs {
    /// Contents of the app log
    var appLog: String?

    /// Contents of the bot log
    var botLog: String?
}
