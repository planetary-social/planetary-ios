//
//  PlistService.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation

class PlistService: BundleSecretsService {

    var dictionary: NSDictionary?

    init(bundle: Bundle = .main) {
        if let path = bundle.path(forResource: "Config", ofType: "plist") {
            dictionary = NSDictionary(contentsOfFile: path)
        }
    }

    func get(key: String) -> String? {
        return dictionary?[key] as? String
    }

}
