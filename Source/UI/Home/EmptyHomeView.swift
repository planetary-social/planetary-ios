//
//  EmptyHomeView.swift
//  Planetary
//
//  Created by Martin Dutra on 5/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct EmptyHomeView: View {

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image.iconPlanetary4
            Text("Welcome!\nThis is your feed")
                .font(.headline)
                .foregroundColor(.primaryTxt)
                .multilineTextAlignment(.center)
            Text(Localized.emptyHomeFeedMessage.text)
                .foregroundColor(.primaryTxt)
                .multilineTextAlignment(.center)
            Button {
                openDirectory()
            } label: {
                Text(Localized.goToYourNetwork.text)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .background(
                        Rectangle()
                            .fill(LinearGradient.horizontalAccent)
                            .cornerRadius(17)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }

    private func openDirectory() {
        guard let mainViewController = appController.mainViewController else {
            return
        }
        mainViewController.selectDirectoryTab()
    }
}

struct EmptyHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                EmptyHomeView()
            }
            VStack {
                EmptyHomeView()
            }
            .preferredColorScheme(.dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg)
        .environmentObject(AppController.shared)
    }
}
