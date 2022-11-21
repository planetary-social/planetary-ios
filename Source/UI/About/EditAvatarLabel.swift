//
//  EditAvatarLabel.swift
//  Planetary
//
//  Created by Martin Dutra on 21/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import Photos
import SwiftUI

struct EditAvatarLabel: View {

    var large: Bool

    private var size: CGFloat {
        large ? 15 : 10
    }

    private var padding: CGFloat {
        large ? 5 : 3
    }

    var body: some View {
        ZStack {
            Image.navIconCamera
                .resizable()
                .frame(width: size, height: size)
        }
        .padding(EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding))
        .background(Circle().fill(LinearGradient.diagonalAccent))
    }
}
