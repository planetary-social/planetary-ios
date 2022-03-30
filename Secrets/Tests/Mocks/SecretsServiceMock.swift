//
//  SecretsServiceMock.swift
//  
//
//  Created by Martin Dutra on 24/11/21.
//

import Foundation
@testable import Secrets

class SecretsServiceMock: SecretsService {

    var value: String?

    func get(key: String) -> String? {
        value
    }
}
