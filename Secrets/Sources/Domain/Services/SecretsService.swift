//
//  SecretsService.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation

protocol SecretsService {
    func get(key: String) -> String?
}
