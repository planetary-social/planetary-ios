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

    func report(error: Error, metadata: [AnyHashable: Any]?) {
        Bugsnag.notifyError(error) { event in
            if let metadata = metadata {
                event.addMetadata(metadata, section: "metadata")
            }
            if let logUrls = Log.fileUrls.first {
                do {
                    let data = try Data(contentsOf: logUrls)
                    let string = String(data: data, encoding: .utf8)
                    event.addMetadata(string, key: "app", section: "logs")
                } catch {
                    Log.optional(error)
                }
            }
            // TODO: Send bot metadata
            return true
        }
    }
}
