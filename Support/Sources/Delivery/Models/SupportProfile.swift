//
//  SupportProfile.swift
//  
//
//  Created by Martin Dutra on 5/4/22.
//

import Foundation

/// An abusive profile the user wants to report
public struct SupportProfile {

    /// The identifier of the abusive profile
    public var identifier: String

    /// The name (if available) of the abusive user
    public var name: String?

    public init(identifier: String, name: String?) {
        self.identifier = identifier
        self.name = name
    }
}
