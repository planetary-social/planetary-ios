//
//  Room.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model for an SSB Room server, used to tunnel connections between SSB peers.
struct Room: Equatable, Identifiable, Hashable {
    
    /// A unique string representing this room.
    var id: String { address.string }
    
    /// The token in the Secrets file
    var token: String?
    
    /// An identifier for the room.
    var identifier: String?
    
    /// The name of the image resource for this room.
    var imageName: String?
    
    /// The multiserver address of the room.
    let address: MultiserverAddress
}
