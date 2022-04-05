//
//  SupportContent.swift
//  
//
//  Created by Martin Dutra on 5/4/22.
//

import Foundation
import UIKit

public struct SupportContent {

    public var identifier: String
    public var profile: SupportProfile?
    public var reason: SupportReason
    public var view: UIView?

    public init(identifier: String, profile: SupportProfile?, reason: SupportReason, view: UIView?) {
        self.identifier = identifier
        self.profile = profile
        self.reason = reason
        self.view = view
    }
}
