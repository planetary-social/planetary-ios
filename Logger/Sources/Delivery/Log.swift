//
//  Log.swift
//  
//
//  Created by Martin Dutra on 10/2/22.
//

import Foundation

/// The Log class provides a simple logging utility that you can use to output messages
///
/// The levels are as follows:
/// - FATAL: An unhandleable error that results in a program crash.
/// - ERROR or UNEXPECTED: A handleable error condition.
/// - INFO:  Generic (useful) information about system operation.
/// - DEBUG: Low-level information for developers.
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
        service.fileUrls
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

    /// URLs in the device's filesystem that contain what was logged in this and previous sessions
    static var fileUrls: [URL] {
        shared.fileUrls
    }

    /// Log a ERROR message
    /// - Returns: True if an error could be unwrapped
    ///
    /// Convenience function that unwraps the error (if exists) and logs its description
    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        shared.optional(error, detail)
    }

    /// Log a INFO message
    static func info(_ string: String) {
        shared.info(string)
    }

    /// Log a DEBUG message
    static func debug(_ string: String) {
        shared.debug(string)
    }

    /// Log a ERROR message
    ///
    /// Convencience function that categorize common errors that the app can handle
    static func unexpected(_ reason: Reason, _ detail: String?) {
        shared.unexpected(reason, detail)
    }

    /// Log a FATAL message
    ///
    /// Convencience function that categorize common errors that the app cannot handle
    static func fatal(_ reason: Reason, _ detail: String?) {
        shared.fatal(reason, detail)
    }

    /// Log a ERROR message
    ///
    /// Convenience function that unwraps an error and a response from a network call
    static func optional(_ error: Error?, from response: URLResponse?) {
        guard let error = error else { return }
        guard let response = response else { return }
        let path = response.url?.path ?? "unknown path"
        let detail = "\(path) \(error)"
        shared.unexpected(.apiError, detail)
    }

    /// Log a ERROR message
    static func error(_ message: String) {
        shared.service.unexpected(message, nil)
    }
}
