//
//  Log.swift
//  
//
//  Created by Martin Dutra on 10/2/22.
//

import Foundation

public class Log {

    public enum Reason: String {
        case apiError
        case botError
        case missingValue
        case incorrectValue
    }

    public static let shared = Log()

    var service: LoggerService

    init(service: LoggerService = LoggerServiceAdapter(fileLoggerService: CocoaLumberjackService())) {
        self.service = service
    }

    public var fileUrls: [URL] {
        return service.fileUrls
    }

    @discardableResult
    public func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        service.optional(error, detail)
    }

    public func info(_ string: String) {
        service.info(string)
    }

    public func debug(_ string: String) {
        service.debug(string)
    }

    public func unexpected(_ reason: Reason, _ detail: String?) {
        service.unexpected(reason.rawValue, detail)
    }

    public func fatal(_ reason: Reason, _ detail: String?) {
        service.fatal(reason.rawValue, detail)
    }

}

public extension Log {

    static var fileUrls: [URL] {
        return shared.fileUrls
    }

    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        shared.optional(error, detail)
    }

    static func info(_ string: String) {
        shared.info(string)
    }

    static func debug(_ string: String) {
        shared.debug(string)
    }

    static func unexpected(_ reason: Reason, _ detail: String?) {
        shared.unexpected(reason, detail)
    }

    static func fatal(_ reason: Reason, _ detail: String?) {
        shared.fatal(reason, detail)
    }

    static func optional(_ error: Error?, from response: URLResponse?) {
        guard let error = error else { return }
        guard let response = response else { return }
        let path = response.url?.path ?? "unknown path"
        let detail = "\(path) \(error)"
        shared.unexpected(.apiError, detail)
    }

    static func error(_ message: String) {
        shared.service.unexpected(message, nil)
    }

}
