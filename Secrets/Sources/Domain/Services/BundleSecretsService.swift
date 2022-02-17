//
//  BundleSecretsService.swift
//  
//
//  Created by Martin Dutra on 6/12/21.
//

import Foundation

protocol BundleSecretsService {

    func get(key: String) -> String?
    
}
