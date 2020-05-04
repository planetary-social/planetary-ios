//
//  BugsnagCrashReporting.swift
//  Planetary
//
//  Created by Martin Dutra on 4/1/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Bugsnag

typealias CrashReporting = BugsnagCrashReporting

class BugsnagCrashReporting: CrashReportingService {
    
    static var shared: CrashReportingService = BugsnagCrashReporting()
    
    private var configured: Bool = false
    
    func configure() {
        guard let token = Environment.Bugsnag.token else {
            configured = false
            return
        }
        Log.info("Configuring Bugsnag...")
        Bugsnag.start(withApiKey: token)
        configured = true
    }
    
    func identify(about: About?, network: NetworkKey) {
        if let about = about, configured {
            Bugsnag.configuration()?.setUser(about.identity,
                                             withName: about.name,
                                             andEmail: nil)
            Bugsnag.addAttribute("key", withValue: network, toTabWithName: "network")
            Bugsnag.addAttribute("name", withValue: network.name, toTabWithName: "network")
        }
    }
    
    func crash() {
        guard configured else {
            return
        }
        Bugsnag.notifyError(NSError(domain: "com.planetary.social", code: 408, userInfo: nil)) { report in
            if let log = Log.fileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["app": string], toTabWithName: "logs")
            }
            if let log = Bots.current.logFileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["bot": string], toTabWithName: "logs")
            }
        }
    }
    
    func record(_ message: String) {
        guard configured else {
            return
        }
        Bugsnag.leaveBreadcrumb(withMessage: message)
    }
    
    func reportIfNeeded(error: Error?) {
        guard configured, let error = error else {
            return
        }
        Bugsnag.notifyError(error) { report in
            if let log = Log.fileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["app": string], toTabWithName: "logs")
            }
            if let log = Bots.current.logFileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["bot": string], toTabWithName: "logs")
            }
        }
    }

    func reportIfNeeded(error: Error?, metadata: [AnyHashable: Any]) {
        guard configured, let error = error else {
            return
        }
        Bugsnag.notifyError(error) { report in
            report.addMetadata(metadata, toTabWithName: "metadata")
            if let log = Log.fileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["app": string], toTabWithName: "logs")
            }
            if let log = Bots.current.logFileUrls.first, let data = try? Data(contentsOf: log), let string = String(data: data, encoding: .utf8) {
                report.addMetadata(["bot": string], toTabWithName: "logs")
            }
        }
    }
    
}
