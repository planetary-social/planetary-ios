//
//  View+RoundedCorner.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

// https://stackoverflow.com/a/58606176/982195
extension View {
    
    /// Allows you to round specific corners of views with different radii. 
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
