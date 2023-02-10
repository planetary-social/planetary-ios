//
//  BotMigrationController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 1/18/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftUI
import UIKit

/// A controller that provides data to the `BotMigrationView`.
class BotMigrationController: BotMigrationViewModel {
    
    /// Indicates that the migration has encountered an error.
    @Published var showError = false
    
    /// Indicates that the migration has completed.
    @Published var isDone = false
    
    /// A reference to the controller hosting the SwiftUI view. Used for dismissal.
    private var hostingController: UIViewController
    
    init(hostingController: UIViewController) {
        self.hostingController = hostingController
    }
    
    func dismissPressed() {
        hostingController.dismiss(animated: true)
    }
    
    func tryAgainPressed() {
        Task {
            await AppController.shared.relaunch()
        }
    }
}
