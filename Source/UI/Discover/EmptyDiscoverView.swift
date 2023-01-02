//
//  EmptyDiscoverView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct EmptyDiscoverView: View {

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image.iconPlanetary4
            Text("Explore Planetary")
                .font(.headline)
                .foregroundColor(.primaryTxt)
                .multilineTextAlignment(.center)
            Text("The expore tab lets you see more people on Planetary. Specifically it's everything the people you follow are following.")
                .foregroundColor(.primaryTxt)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(60)
    }
}

struct EmptyDiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                EmptyDiscoverView()
            }
            VStack {
                EmptyDiscoverView()
            }
            .preferredColorScheme(.dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg)
        .environmentObject(AppController.shared)
    }
}
