//
//  PlaceholderModifier.swift
//  Planetary
//
//  Created by Matthew Lorentz on 8/3/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

// https://stackoverflow.com/a/57715771/982195
extension View {
    /// Overlays a placeholder view on top of this view. Useful for customizng the styling of a text placeholder in a
    /// `TextField`.
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
