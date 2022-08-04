//
//  Room.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A model for an SSB Room server, used to tunnel connections between SSB peers.
struct Room: Equatable, Identifiable {
    
    /// A unique string representing this room.
    var id: String { address.string }
    
    /// The multiserver address of the room.
    let address: MultiserverAddress
}
