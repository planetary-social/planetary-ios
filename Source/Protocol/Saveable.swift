//
//  Saveable.swift
//  FBTT
//
//  Created by Christoph on 5/15/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Convenience type for the completion handler.
typealias SaveCompletion = ((Saveable) -> Void)

@objc protocol Saveable {

    /// Indicates if the protocol is ready for `save()` to be called.
    /// This is useful to control UI's enabled state.
    var isReadyToSave: Bool { get }

    /// Convenience handler that should be called at the end of `save()`.
    /// It is purposefully not an argument to `save()` to allow for better
    /// separation of work and post-work steps.
    var saveCompletion: SaveCompletion? { get set }

    /// Implementors should call `self.saveCompletion()` when work is finished.
    func save()
}

protocol SaveableDelegate: AnyObject {

    /// Indicates when this protocol has changed `isReadyToSave` state.
    func saveable(_ saveable: Saveable, isReadyToSave: Bool)
}
