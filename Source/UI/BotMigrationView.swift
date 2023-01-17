//
//  BotMigrationView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol BotMigrationViewModel: ObservableObject {
    func dismissPressed()
}

/// A view to show the user while they are upgrading from GoBot version "beta1" to "beta2"
struct BotMigrationView<ViewModel>: View where ViewModel: BotMigrationViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        HStack {
            Spacer()
            ZStack {
                // Blurred background
                VStack {
                    Spacer()
                    Image.iconPlanetary2
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Spacer()
                }
                .frame(maxWidth: 375)
                .blur(radius: 90)
                
                // Foreground
                VStack(spacing: 0) {
                    VerticallyCenteringScrollView {
                        VStack(spacing: 30) {
                            Color.clear.frame(width: 0, height: 60)
                            HStack {
                                Spacer()
                                Image.iconPlanetary5
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 218.3)
                                Spacer()
                            }
                            Localized.botMigrationBodyText.view
                                .font(.body)
                                .foregroundColor(.mainText)
                                .padding()
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                            
                            ProgressView()
                                .scaleEffect(2)
                                .accentColor(.mainText)
                            
                            Spacer()

                            BigActionButton(title: .startUsingPlanetary) {
                                viewModel.dismissPressed()
                            }
                            .frame(width: 286)
                            
                            Color.clear.frame(width: 0, height: 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea([.top, .bottom])
            }
            
            Spacer()
        }
        .background(
            Color.appBackground.edgesIgnoringSafeArea(.all)
        )
    }
}

fileprivate class PreviewViewModel: BotMigrationViewModel {
    func dismissPressed() {}
}

struct BotMigrationView_Previews: PreviewProvider {
    static var previews: some View {
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPhone 14 Pro")
        
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPhone SE (3rd generation)")
        
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPad (10th generation)")
    }
}
