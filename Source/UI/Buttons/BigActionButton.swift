//
//  BigGradientButton.swift
//  Planetary-scuttle
//
//  Created by Matthew Lorentz on 1/17/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A big bright button that is used as the primary call-to-action on a screen.
struct BigActionButton: View {
    
    var title: Localized
    var action: () -> Void
    
    var body: some View {
        Button(action: action, label: {
            Localized.startUsingPlanetaryTitle.view
                .transition(.opacity)
                .font(.headline)
        })
        .lineLimit(nil)
        .foregroundColor(.black)
        .buttonStyle(BigActionButtonStyle())
    }
}

struct BigActionButtonStyle: ButtonStyle {
    
    @SwiftUI.Environment(\.isEnabled) private var isEnabled
    
    let cornerRadius: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // Button shadow/background
            ZStack {
                Color(hex: "#A04651")
            }
            .cornerRadius(80)
            .offset(y: 7.5)
            .shadow(color: Color(white: 0, opacity: 0.2), radius: 20, x: 0, y: 20)
            
            // Button face
            ZStack {
                // Gradient background color
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 1, blue: 1, opacity: 0.2),
                            Color(red: 1, green: 1, blue: 1, opacity: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .blendMode(.softLight)
                    
                    LinearGradient(
                        colors: [
                            Color(hex: "#F08508"),
                            Color(hex: "#F43F75")
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                    .blendMode(.normal)
                }
                
                // Text container
                configuration.label
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(15)
                    .shadow(
                        color: Color(white: 0, opacity: 0.15),
                        radius: 2,
                        x: 0,
                        y: 2
                    )
                    .opacity(isEnabled ? 1 : 0.5)
            }
            .cornerRadius(cornerRadius)
            .offset(y: configuration.isPressed ? 6 : 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct BigGradientButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            BigActionButton(title: Localized.startUsingPlanetaryTitle, action: {})
                .frame(width: 268)
            
            BigActionButton(title: Localized.startUsingPlanetaryTitle, action: {})
                .disabled(true)
                .frame(width: 268)
        }
    }
}
