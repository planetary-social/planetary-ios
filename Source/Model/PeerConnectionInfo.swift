//
//  PeerConnectionInfo.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model representing a scuttlebutt peer that the GoBot is syncing with, or has recently synced with.
struct PeerConnectionInfo: Identifiable, Equatable {

    /// The public key for this user, without a sigil ('@') or feed identifier ('=.ed25519')
    let id: String
    let identity: Identity?
    let name: String?
    let imageMetadata: ImageMetadata?
    var isActive: Bool
    
    init(
        id: String,
        identity: Identity? = nil,
        name: String? = nil,
        imageMetadata: ImageMetadata? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.identity = identity
        self.name = name
        self.imageMetadata = imageMetadata
        self.isActive = isActive
    }
    
    init(about: About) {
        self.id = about.about.id
        self.identity = about.about
        self.name = about.name ?? id
        self.imageMetadata = about.image
        self.isActive = true
    }
}
