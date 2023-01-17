//
//  CardButtonStyle.swift
//  Planetary
//
//  Created by Martin Dutra on 12/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .compositingGroup()
            .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
            .shadow(
                color: .cardShadowBottom,
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
    }
}
