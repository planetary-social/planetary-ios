//
//  Beta1MigrationView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol Beta1MigrationViewModel: ProgressButtonViewModel {
    var progress: Float { get }
    var shouldConfirmDismissal: Bool { get set }
    func dismissPressed()
    func confirmDismissal()
}

/// A view to show the user while they are upgrading from GoBot version "beta1" to "beta2"
struct Beta1MigrationView<ViewModel>: View where ViewModel: Beta1MigrationViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        HStack {
            Spacer()
            ZStack {
                // Blurred background
                VStack {
                    Image("icon-planetary-2")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    Spacer()
                }
                .frame(maxWidth: 375)
                .blur(radius: 90)
                
                // Foreground
                VStack(spacing: 0) {
                    Spacer()
                    VerticallyCenteringScrollView {
                        VStack(spacing: 30) {
                            Color.clear.frame(width: 0, height: 40)
                            HStack {
                                Image("icon-planetary-2")
                                    .resizable()
                                    .frame(width: 72.11, height: 88)
                                Spacer()
                            }
                            Localized.upgradingAndRestoring.view
                                .font(.title)
                                .foregroundColor(Color("mainText"))
                                .multilineTextAlignment(.leading)
                            
                            Beta1MigrationDescriptionText(viewModel: viewModel)
                            
                            Spacer()
                            
                            if viewModel.progress < 0.995 {
                                Button {
                                    viewModel.confirmDismissal()
                                } label: {
                                    Localized.dismissAndStartUsingPlanetary.view
                                        .foregroundColor(Color(UIColor.linkColor))
                                        .font(.callout)
                                        .underline()
                                        .bold()
                                }
                            }

                            ProgressButton(viewModel: viewModel)
                            
                            Color.clear.frame(width: 0, height: 10)
                        }
                        .frame(maxWidth: 287, maxHeight: 800)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea([.top, .bottom])
            }
            
            Spacer()
        }
        .alert(isPresented: $viewModel.shouldConfirmDismissal, content: {
            Alert(
                title: Localized.areYouSure.view,
                message: Localized.dismissMigrationEarlyMessage.view,
                primaryButton: .default(Localized.yes.view, action: {
                    viewModel.dismissPressed()
                }),
                secondaryButton: .destructive(Localized.cancel.view, action: {
                    viewModel.shouldConfirmDismissal = false
                })
            )
        })
        .background(
            Color("appBackground").edgesIgnoringSafeArea(.all)
        )
    }
}

fileprivate class PreviewViewModel: Beta1MigrationViewModel {
    
    var progress: Float
    var shouldConfirmDismissal = false
    
    init(progress: Float) {
        self.progress = progress
    }
    
    func dismissPressed() {}
    func confirmDismissal() {}
}

struct Beta1MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        Beta1MigrationView(viewModel: PreviewViewModel(progress: 0.66))
        
        Beta1MigrationView(viewModel: PreviewViewModel(progress: 0.66))
            .preferredColorScheme(.dark)
        
        Beta1MigrationView(viewModel: PreviewViewModel(progress: 0.995))
            .preferredColorScheme(.dark)
        
        Beta1MigrationView(viewModel: PreviewViewModel(progress: 0.66))
            .previewDevice("iPhone SE (2nd generation)")
        
        Beta1MigrationView(viewModel: PreviewViewModel(progress: 0.66))
            .previewDevice("iPad Air (4th generation)")
    }
}
