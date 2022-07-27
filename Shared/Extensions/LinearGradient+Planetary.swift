//
//  LinearGradient+Planetary.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

extension LinearGradient {
    
    public static let horizontalAccent = LinearGradient(
        colors: [ Color(hex: "#F08508"), Color(hex: "#F43F75")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    public static let diagonalAccent = LinearGradient(
        colors: [ Color(hex: "#F08508"), Color(hex: "#F43F75")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let solidBlack = LinearGradient(
        colors: [Color.black],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
