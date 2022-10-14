//
//  VerticallyCenteringScrollView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A scroll view that vertically centers its content if it doesn't fill the screen.
/// From: https://stackoverflow.com/a/69695324/982195
struct VerticallyCenteringScrollView<Content>: View where Content: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                content
                    .frame(width: geometry.size.width)
                    .frame(minHeight: geometry.size.height)
            }
        }
    }
}
