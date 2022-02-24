//
//  PeerConnectionInfo.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

struct PeerConnectionInfo: Identifiable, Equatable {
    var id: Identity
    var name: String?
    var imageID: BlobIdentifier?
    var currentlyActive: Bool
}
