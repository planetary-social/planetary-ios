//
//  SupportArticle.swift
//  
//
//  Created by Martin Dutra on 24/3/22.
//

import Foundation

/// An article entry in Support documentation
public enum SupportArticle: String {
    
    /// FAQ
    case frequentlyAskedQuestions

    /// Privacy Policy
    case privacyPolicy

    /// Terms of Service
    case termsOfService

    /// General information about Planetary
    case whatIsPlanetary

    /// Information about why the user cannot edit posts once published
    case editPost
}
