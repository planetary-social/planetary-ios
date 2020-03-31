//
//  AppDelegate+UniversalLink.xcconfig
//  Planetary
//
//  Created by Martin Dutra on 3/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppDelegate {
    
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return false
        }
        
        Log.info("Incoming URL: \(incomingURL)")

        if let identifier = Identifier.parse(publicLink: incomingURL) {
            Log.info("Identifier = \(identifier)")
            
            AppController.shared.open(identity: identifier)
            
            return true
        }
        
        return false
    }
}

