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

    func get(key: String) -> String? {
        if let result = bundleSecretsService.get(key: key), !result.isEmpty {
            Log.debug("Key \(key) found.")
            return result
        } else {
            Log.error("Key \(key) not found.")
            return nil
        }
    }

}
