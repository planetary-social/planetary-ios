//
//  PillButtonStyle.swift
//  Planetary
//
//  Created by Chad Sarles on 11/24/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct PillButtonStyle: ButtonStyle {
    @SwiftUI.Environment(\.isEnabled) private var isEnabled
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                !isEnabled ? Color.pillButtonBackgroundDisabled :
                    configuration.isPressed ? Color.pillButtonBackgroundPressed : Color.pillButtonBackground
            )
            .foregroundColor(isEnabled ? Color.pillButtonText : Color.pillButtonTextDisabled)
            .clipShape(Capsule())
    }
}
