//
//  FileLoggerService.swift
//  
//
//  Created by Martin Dutra on 10/2/22.
//

import Foundation

protocol FileLoggerService {

    var fileUrls: [URL] { get }

    func debug(_ string: String)

    func info(_ string: String)

    func error(_ string: String)
}
