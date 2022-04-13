//
//  SupportReason.swift
//  
//
//  Created by Martin Dutra on 24/3/22.
//

import Foundation

/// A reason why the user is reporting an offensive content
public enum SupportReason: String, CaseIterable {

    /// It makes abusive use of the social network
    case abusive

    /// It breaches copyright laws
    case copyright

    /// It is offensive for the user
    case offensive

    /// Any other reason
    case other
}
