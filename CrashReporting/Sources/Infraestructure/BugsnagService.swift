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

    init(keys: Keys = Keys.shared) {
        guard let apiKey = keys.get(key: .bugsnag) else {
            Log.info("Error while configuring Bugsnag. ApiKey does not exist.")
            return
        }
        Log.info("Configuring Bugsnag...")
        Bugsnag.start(withApiKey: apiKey)
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
