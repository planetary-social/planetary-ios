//
//  Room.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/2/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Room: Equatable, Identifiable {
    
    var id: String { address.string }
    
    let address: MultiserverAddress
}
