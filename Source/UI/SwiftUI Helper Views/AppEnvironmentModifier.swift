//
//  AppEnvironmentModifier.swift
//  Planetary
//
//  Created by Martin Dutra on 26/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

extension View {
    /// Sets the `BotRepository` and `AppController` environment objects.
    func injectAppEnvironment(
        botRepository: BotRepository = .shared,
        appController: AppController = .shared
    ) -> some View {
        self
            .environmentObject(botRepository)
            .environmentObject(appController)
    }
}
