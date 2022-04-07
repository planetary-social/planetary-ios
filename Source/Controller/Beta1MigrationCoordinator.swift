//
//  Beta1MigrationCoordinator.swift
//  Planetary
//
//  Created by Matthew Lorentz on 4/7/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import SwiftUI

class Beta1MigrationCoordinator: ObservableObject, Beta1MigrationViewModel {
    
    private var dismissHandler: () -> Void
    
    init(dismissHandler: @escaping () -> Void) {
        self.dismissHandler = dismissHandler
    }
    
    static func presentMigrationView(on viewController: UIViewController) {
        let coordinator = Beta1MigrationCoordinator(dismissHandler: {
            viewController.dismiss(animated: true)
        })
        let view = Beta1MigrationView(viewModel: coordinator)
        let hostingController = UIHostingController(rootView: view)
        viewController.present(hostingController, animated: true)
        
    }
    
    func dismissPressed() {
         dismissHandler()
    }
}
