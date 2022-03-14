//
//  Monitor.swift
//
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation

public class Monitor {

    public static let shared = Monitor(service: MonitorServiceAdapter(apiService: BugsnagService()))

    var service: MonitorService

    init(service: MonitorService) {
        self.service = service
    }

    public func identify(identifier: String, name: String?, networkKey: String, networkName: String) {
        let identity = Identity(identifier: identifier,
                                name: name,
                                networkKey: networkKey,
                                networkName: networkName)
        service.identify(identity: identity)
    }

    public func forget() {
        service.forget()
    }

    public func crash() {
        let error = NSError(domain: "com.planetary.social", code: 408, userInfo: nil)
        service.report(error: error, metadata: nil)
    }

    public func record(_ message: String) {
        service.record(message)
    }

    public func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any]? = nil) {
        if let error = error {
            service.report(error: error, metadata: metadata)
        }
    }

}
