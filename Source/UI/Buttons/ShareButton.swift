//
//  ShareButton.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/6/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A standard iOS share button (square with arrow pointing up)
struct ShareButton: View {
    
    @Binding var disabled: Bool
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 20))
                .padding(16)
                .foregroundColor(disabled ? Color.gray : Color.white)
        }
        .disabled(disabled)
    }
}

struct ShareButton_Previews: PreviewProvider {
    static var previews: some View {
        ShareButton(disabled: .constant(true)) {}
            .background(Color.black)
    }
}
