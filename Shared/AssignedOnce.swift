//
//  AssignedOnce.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A wrapper that only lets you write to a variable once. This rule is enforced at compile time and is a good
/// alternative to force-unwrapping properties in UIViewControllers.
/// https://blog.steveasleep.com/three-uikit-protips?utm_campaign=iOS%252BDev%252BWeekly&utm_medium=email&utm_source=iOS%252BDev%252BWeekly%252BIssue%252B574
@propertyWrapper
public struct AssignedOnce<T> {
  #if DEBUG
    private var hasBeenAssignedNotNil = false
  #endif

  public private(set) var value: T!

  public var wrappedValue: T! {
    get { value }
    
    // Normally you don't want to be running a bunch of extra code when storing values, but
    // since you should only be doing it one time, it's not so bad.
    set {
      #if DEBUG
        assert(!hasBeenAssignedNotNil)
        if newValue != nil {
          hasBeenAssignedNotNil = true
        }
      #endif

      value = newValue
    }
  }

  public init(wrappedValue initialValue: T?) {
    wrappedValue = initialValue
  }
}
