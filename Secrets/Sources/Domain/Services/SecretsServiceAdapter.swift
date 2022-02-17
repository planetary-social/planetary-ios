//
//  File.swift
//  
//
//  Created by Martin Dutra on 1/12/21.
//

import Foundation
import Logger

class SecretsServiceAdapter: SecretsService {

    var bundleSecretsService: BundleSecretsService

    init(bundleSecretsService: BundleSecretsService) {
        self.bundleSecretsService = bundleSecretsService
    }

    func get(key: Key) -> String? {
        if let result = bundleSecretsService.get(key: key.rawValue) {
            Log.debug("Key \(key) found.")
            return result
        } else {
            Log.info("Key \(key) not found.")
            return nil
        }
    }

}
