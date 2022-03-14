//
//  CrashReporting.swift
//
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation

public class CrashReporting {

    public static let shared = CrashReporting(service: CrashReportingServiceAdapter(api: BugsnagService()))

    var service: CrashReportingService

    init(service: CrashReportingService) {
        self.service = service
    }

    /// Identifies user information on this session
    public func identify(identifier: String, name: String?, networkKey: String, networkName: String) {
        let identity = Identity(identifier: identifier,
                                name: name,
                                networkKey: networkKey,
                                networkName: networkName)
        service.identify(identity: identity)
    }

    /// Removes user information on this session
    public func forget() {
        service.forget()
    }

    /// Sends a custom error to the Crash Reporting service
    ///
    /// This function is useful for testing if the crash reporting tool is actually working
    public func crash() {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        service.report(error: error, metadata: nil)
    }

    /// Records a message useful for debugging
    public func record(_ message: String) {
        service.record(message)
    }

    /// Send an error, if it exists, to the Crash Reporting service
    public func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any]? = nil) {
        if let error = error {
            service.report(error: error, metadata: metadata)
        }
    }

}
