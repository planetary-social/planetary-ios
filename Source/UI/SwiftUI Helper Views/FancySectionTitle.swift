//
//  FancySectionTitle.swift
//  Planetary
//
//  Created by Matthew Lorentz on 7/20/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A text view that displays an icon and a title in small caps with a gradient foreground color.
struct FancySectionTitle: View {

    var gradient: LinearGradient
    var image: Image
    var text: String
    
    var body: some View {
        HStack(spacing: 6) {
            gradient
                .mask(
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: .infinity)
                .fixedSize(horizontal: true, vertical: false)
            Text(text)
                .font(.subheadline.smallCaps())
                .foregroundLinearGradient(gradient)
                .frame(maxHeight: .infinity)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct FancySectionTitle_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            VStack {
                FancySectionTitle(
                    gradient: LinearGradient.diagonalAccent,
                    image: Image.tabIconHome,
                    text: "Home"
                )
                
                FancySectionTitle(
                    gradient: LinearGradient.diagonalAccent,
                    image: Image.tabIconHome,
                    text: "Home"
                )
                .environment(\.sizeCategory, .extraExtraExtraLarge)
            }
            .padding()
        }
        .background(Color.menuBorderColor)
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}
