//
//  OffensiveContent.swift
//  
//
//  Created by Martin Dutra on 5/4/22.
//

import Foundation
import UIKit

/// An offensive content the user wants to report
public struct OffensiveContent {

    /// The identifier of the content in scuttlebutt
    public var identifier: String

    /// The creator of the offensive content
    public var profile: AbusiveProfile?

    /// A reason why the user is reporting the offensive content
    public var reason: SupportReason

    /// A view that is displaying the offensive content, it will be used to take a screenshot
    public var view: UIView?

    public init(identifier: String, profile: AbusiveProfile?, reason: SupportReason, view: UIView?) {
        self.identifier = identifier
        self.profile = profile
        self.reason = reason
        self.view = view
    }
}
