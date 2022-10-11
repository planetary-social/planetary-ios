//
//  ProgressButton.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/21/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

// swiftlint:disable function_body_length

protocol ProgressButtonViewModel: ObservableObject {
    func dismissPressed()
    var progress: Float { get }
}

/// A view to show the user while they are upgrading from GoBot version "beta1" to "beta2"
struct ProgressButton<ViewModel>: View where ViewModel: ProgressButtonViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        Button(action: viewModel.dismissPressed, label: {
            if viewModel.progress < 0.995 {
                HStack(alignment: .bottom, spacing: 3) {
                    Spacer()
                    Text(
                        String(
                            format: "%.0f%% \(Localized.percentComplete.text)",
                            viewModel.progress * 100
                        )
                    )
                    .font(.headline)
                    
                    LottieAnimation(name: "bouncing_ellipse")
                        .frame(width: 26, height: 14)
                        .padding(.bottom, -1)
                    
                    Spacer()
                }
            } else {
                Localized.startUsingPlanetaryTitle.view
                    .transition(.opacity)
                    .animation(.easeIn, value: viewModel.progress)
                    .font(.headline)
            }
        })
        .frame(height: 51)
        .frame(maxWidth: 286)
        .foregroundColor(.black)
        .buttonStyle(ProgressButtonStyle(viewModel: viewModel))
        .disabled(viewModel.progress < 0.995)
    }
}

struct ProgressButtonStyle<ViewModel>: ButtonStyle where ViewModel: ProgressButtonViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            GeometryReader { geometry in
                // Button shadow/background
                ZStack {
                    Color(hex: "#A0468C")
                    
                    HStack {
                        Spacer()
                        Color.black
                            .opacity(0.5)
                            .frame(width: geometry.size.width * CGFloat(1 - viewModel.progress))
                    }
                    .animation(.easeIn, value: viewModel.progress)
                }
                .cornerRadius(11.2)
                .offset(y: 7.5)
                .shadow(color: Color(white: 0, opacity: 0.2), radius: 20, x: 0, y: 20)
                
                // Button face
                ZStack {
                    // Gradient background color
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 1, blue: 1, opacity: 0.2),
                                Color(red: 1, green: 1, blue: 1, opacity: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .blendMode(.softLight)
                        
                        LinearGradient(
                            colors: [
                                Color(hex: "#D54AF9"),
                                Color(hex: "#FF836F")
                            ],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                        .blendMode(.normal)
                    }
                    
                    // Opacity overlay to show progress
                    HStack {
                        Spacer()
                        Color.black
                            .opacity(0.4)
                            .frame(width: geometry.size.width * CGFloat(1 - viewModel.progress))
                    }
                    .animation(.easeIn, value: viewModel.progress)
                    
                    // Text container
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            configuration.label
                                .foregroundColor(.white)
                                .font(.headline)
                                .shadow(
                                    color: Color(white: 0, opacity: 0.15),
                                    radius: 2,
                                    x: 0,
                                    y: 2
                                )
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .cornerRadius(11.2)
            }
        }
        .offset(y: configuration.isPressed ? 10 : 0)
    }
}

fileprivate class PreviewViewModel: ProgressButtonViewModel {
    var progress: Float
    
    init(progress: Float) {
        self.progress = progress
    }
    
    func dismissPressed() {}
}

struct ProgressButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            ProgressButton(viewModel: PreviewViewModel(progress: 0))
            ProgressButton(viewModel: PreviewViewModel(progress: 0.33))
            ProgressButton(viewModel: PreviewViewModel(progress: 0.6548))
            ProgressButton(viewModel: PreviewViewModel(progress: 1))
        }
        .padding(30)
        .background(Color("appBackground"))
        .preferredColorScheme(.dark)
        .previewLayout(.sizeThatFits)
    }
}
