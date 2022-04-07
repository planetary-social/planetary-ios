//
//  Beta1MigrationView.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

protocol Beta1MigrationViewModel: ObservableObject {
    func dismissPressed()
}

/// A view to show the user while they are upgrading from GoBot version "beta1" to "beta2"
struct Beta1MigrationView<ViewModel>: View where ViewModel: Beta1MigrationViewModel {
    
    @ObservedObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            SwiftUI.Text("Upgrade in progress")
            
            Button("I'm done waiting") {
                viewModel.dismissPressed()
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.yellow.cornerRadius(8))
        }
    }
}

fileprivate class PreviewViewModel: Beta1MigrationViewModel {
    func dismissPressed() {}
}
struct Beta1MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        Beta1MigrationView(viewModel: PreviewViewModel())
    }
}
