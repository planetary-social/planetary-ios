//
//  BundleSecretsServiceMock.swift
//  
//
//  Created by Martin Dutra on 8/12/21.
//

import Foundation
@testable import Secrets

class BundleSecretsServiceMock: BundleSecretsService {

    var value: String?

    func get(key: String) -> String? {
        return value
    }

}
