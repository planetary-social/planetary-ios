//
//  EmptyDiscoverView.swift
//  Planetary
//
//  Created by Martin Dutra on 1/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view is used when the DiscoverView feed doesn't have messages to show.
///
/// It displays an explanation on what DiscoverView is for.
struct EmptyDiscoverView: View {

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image.iconPlanetary4
            Localized.Discover.emptyTitle.view
                .font(.headline)
                .foregroundColor(.primaryTxt)
                .multilineTextAlignment(.center)
            Localized.Discover.emptyDescription.view
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
