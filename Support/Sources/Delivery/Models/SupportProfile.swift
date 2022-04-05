//
//  SupportProfile.swift
//  
//
//  Created by Martin Dutra on 5/4/22.
//

import Foundation

public struct SupportProfile {

    public var identifier: String
    public var name: String?

    public init(identifier: String, name: String?) {
        self.identifier = identifier
        self.name = name
    }
}
