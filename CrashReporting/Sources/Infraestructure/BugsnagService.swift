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
    
    init(keys: Keys = Keys.shared, logger: LogProtocol = Log.shared) {
        guard let apiKey = keys.get(key: .bugsnag) else {
            Log.info("Error while configuring Bugsnag. ApiKey does not exist.")
            return
        }
        Log.info("Configuring Bugsnag...")
        let config = BugsnagConfiguration.loadConfig()
        config.apiKey = apiKey
        config.addOnSendError { (event) -> Bool in
            let shouldAddAppLog: Bool
            if let logs = event.getMetadata(section: "logs") {
                shouldAddAppLog = logs.value(forKey: "app") == nil
            } else {
                shouldAddAppLog = true
            }
            guard shouldAddAppLog, let logUrls = logger.fileUrls.first else {
                return true
            }
            do {
                let data = try Data(contentsOf: logUrls)
                let string = String(data: data, encoding: .utf8)
                event.addMetadata(string, key: "app", section: "logs")
            } catch {
                logger.optional(error, nil)
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

    func report(error: Error, metadata: [AnyHashable: Any]?, appLog: String?, botLog: String?) {
        Bugsnag.notifyError(error) { event in
            if let metadata = metadata {
                event.addMetadata(metadata, section: "metadata")
            }
            if let string = appLog {
                event.addMetadata(string, key: "app", section: "logs")
            }
            if let string = botLog {
                event.addMetadata(string, key: "bot", section: "logs")
            }
            return true
        }
    }
}
