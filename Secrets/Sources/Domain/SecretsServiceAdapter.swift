//
//  File.swift
//  
//
//  Created by Martin Dutra on 1/12/21.
//

import Foundation
import Logger

class SecretsServiceAdapter: SecretsService {

    var dictionary: NSDictionary?

    init(bundle: Bundle = .main) {
        if let path = bundle.path(forResource: "Secrets", ofType: "plist") {
            dictionary = NSDictionary(contentsOfFile: path)
        }
    }

    func get(key: String) -> String? {
        let value = dictionary?[key] as? String
        if let result = value, !result.isEmpty {
            Log.debug("Key \(key) found.")
            return result
        } else {
            Log.error("Key \(key) not found.")
            return nil
        }
    }
}
