//
//  BugsnagCrashReporting.swift
//  Planetary
//
//  Created by Martin Dutra on 4/1/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Bugsnag
import Keys
import Logger

class BugsnagCrashReporting: CrashReportingService {
    
    init() {
        Log.info("Configuring Bugsnag...")
        let keys = PlanetaryKeys()
        Bugsnag.start(withApiKey: keys.bugsnagCrashReportingToken)
    }
    
    func identify(about: About?, network: NetworkKey) {
        if let about = about {
            Bugsnag.configuration()?.setUser(about.identity,
                                             withName: about.name,
                                             andEmail: nil)
            Bugsnag.addAttribute("key", withValue: network, toTabWithName: "network")
            Bugsnag.addAttribute("name", withValue: network.name, toTabWithName: "network")
        }
    }
    
    func forget() {
        Bugsnag.configuration()?.setUser(nil, withName: nil, andEmail: nil)
        Bugsnag.clearTab(withName: "network")
    }
    
    func crash() {
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
        Bugsnag.leaveBreadcrumb(withMessage: message)
    }
    
    func reportIfNeeded(error: Error?) {
        guard let error = error else {
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
        guard let error = error else {
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
