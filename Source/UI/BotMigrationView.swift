//
//  BotMigrationView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol BotMigrationViewModel: ObservableObject {
    var showError: Bool { get set }
    var isDone: Bool { get set }
    func dismissPressed()
    func tryAgainPressed()
}

/// A view to show the user while the Bot performs migrations
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
                            Spacer(minLength: 60)

                            HStack(alignment: .center) {
                                Image.iconPlanetary5
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 200)
                            }
                            
                            Localized.botMigrationBody.view
                                .font(.body)
                                .foregroundColor(.mainText)
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                                .multilineTextAlignment(.center)
                            
                            Spacer(minLength: 0)
                            
                            if !viewModel.isDone {
                                ProgressView()
                                    .scaleEffect(2)
                                    .accentColor(.mainText)
                            } else {
                                Localized.success.view
                                    .font(.body)
                                    .foregroundColor(.mainText)
                                    .multilineTextAlignment(.center)
                            }

                            Spacer(minLength: 0)

                            BigActionButton(title: .startUsingPlanetaryTitle) {
                                viewModel.dismissPressed()
                            }
                            .frame(width: 286)
                            .disabled(!viewModel.isDone)

                            Spacer(minLength: 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea([.top, .bottom])
            }
            
            Spacer()
        }
        .alert(isPresented: $viewModel.showError, content: {
            Alert(
                title: Localized.error.view,
                message: Localized.botMigrationGenericError.view,
                dismissButton: .default(
                    Localized.tryAgain.view,
                    action: viewModel.tryAgainPressed
                )
            )
        })
        .background(
            Color.appBackground.edgesIgnoringSafeArea(.all)
        )
    }
}

fileprivate class PreviewViewModel: BotMigrationViewModel {
    @Published var showError = false
    @Published var isDone = false
    func dismissPressed() {}
    func tryAgainPressed() {
        showError = false
    }
}

struct BotMigrationView_Previews: PreviewProvider {
    
    fileprivate static var errorViewModel: PreviewViewModel = {
        let viewModel = PreviewViewModel()
        viewModel.showError = true
        return viewModel
    }()
    
    fileprivate static var doneViewModel: PreviewViewModel = {
        let viewModel = PreviewViewModel()
        viewModel.isDone = true
        return viewModel
    }()
    
    static var previews: some View {
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPhone 14 Pro")
        
        BotMigrationView(viewModel: errorViewModel)
            .previewDevice("iPhone 14 Pro")
        
        BotMigrationView(viewModel: doneViewModel)
            .previewDevice("iPhone 14 Pro")
        
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPhone SE (3rd generation)")
        
        BotMigrationView(viewModel: PreviewViewModel())
            .previewDevice("iPad (10th generation)")
    }
}
