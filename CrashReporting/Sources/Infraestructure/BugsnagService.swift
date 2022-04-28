//
//  BugsnagService.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation
import Bugsnag
import Secrets
import Logger

class BugsnagService: APIService {

    var onEventHandler: (() -> Logs)?
    
    init(keys: Keys = Keys.shared, logger: LogProtocol = Log.shared) {
        guard let apiKey = keys.get(key: .bugsnag) else {
            Log.info("Error while configuring Bugsnag. ApiKey does not exist.")
            return
        }
        Log.info("Configuring Bugsnag...")
        let config = BugsnagConfiguration.loadConfig()
        config.apiKey = apiKey
        config.addOnSendError { [weak self] (event) -> Bool in
            guard let logs = self?.onEventHandler?() else {
                return true
            }
            var shouldAddAppLog = true
            var shouldAddBotLog = true
            if let logs = event.getMetadata(section: "logs") {
                shouldAddAppLog = logs.value(forKey: "app") == nil
                shouldAddBotLog = logs.value(forKey: "bot") == nil
            }
            if shouldAddAppLog, let log = logs.appLog {
                event.addMetadata(log, key: "app", section: "logs")
            }
            if shouldAddBotLog, let log = logs.botLog {
                event.addMetadata(log, key: "bot", section: "logs")
            }
            return true
        }
        Bugsnag.start(with: config)
    }

    func identify(identity: Identity) {
        Bugsnag.setUser(
            identity.identifier,
            withEmail: nil,
            andName: identity.name
        )
        Bugsnag.addMetadata(identity.networkKey, key: "key", section: "network")
        Bugsnag.addMetadata(identity.networkName, key: "name", section: "network")
    }

    func forget() {
        Bugsnag.setUser(nil, withEmail: nil, andName: nil)
        Bugsnag.clearMetadata(section: "network")
    }

    func record(_ message: String) {
        Bugsnag.leaveBreadcrumb(withMessage: message)
    }

    func report(error: Error, metadata: [AnyHashable: Any]?) {
        Bugsnag.notifyError(error) { [weak self] event in
            if let metadata = metadata {
                event.addMetadata(metadata, section: "metadata")
            }
            let logs = self?.onEventHandler?()
            if let string = logs?.appLog {
                event.addMetadata(string, key: "app", section: "logs")
            }
            if let string = logs?.botLog {
                event.addMetadata(string, key: "bot", section: "logs")
            }
            return true
        }
    }
}
