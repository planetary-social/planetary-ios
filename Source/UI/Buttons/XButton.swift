//
//  XButton.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/6/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// An X button used for closing things
struct XButton: View {
    var action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            let xmark = Image(systemName: "xmark")
                .font(.system(size: 20))
                .padding(16)
                .foregroundColor(Color.white)
            
            xmark
        }
    }
}

struct XButton_Previews: PreviewProvider {
    static var previews: some View {
        XButton(action: {})
            .background(Color.black)
    }
}
