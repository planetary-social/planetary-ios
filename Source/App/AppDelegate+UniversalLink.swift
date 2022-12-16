//
//  AppDelegate+UniversalLink.xcconfig
//  Planetary
//
//  Created by Martin Dutra on 3/2/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

extension AppDelegate {
    
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return false
        }
        
        Log.info("Incoming URL: \(incomingURL)")
        
        var alias: String
        
        // Look for an alias in this format: https://alias.host.com
        if let host = incomingURL.host,
            incomingURL.path.replacingOccurrences(of: "/", with: "").isEmpty,
            host.components(separatedBy: ".").count > 1,
            let aliasComponent = host.components(separatedBy: ".").first {
            
            alias = aliasComponent
            return AppController.shared.open(url: incomingURL, alias: alias)
        // Look for an alias in this format: https://host.com/alias
        } else if incomingURL.path.components(separatedBy: "/").count == 2,
            let aliasComponent = incomingURL.path.components(separatedBy: "/").last {
            
            alias = aliasComponent
            return AppController.shared.open(url: incomingURL, alias: alias)
        }
        
        if let identifier = Identifier.parse(publicLink: incomingURL) {
            Log.info("Identifier = \(identifier)")
            switch identifier.sigil {
            case .blob:
                AppController.shared.pushBlobViewController(for: identifier)
            case .message:
                AppController.shared.pushThreadViewController(for: identifier)
            case .feed:
                AppController.shared.pushViewController(for: .about, with: identifier)
            default:
                CrashReporting.shared.reportIfNeeded(error: AppError.unexpected)
                return false
            }
            return true
        } else if let hashtag = Hashtag.parse(publicLink: incomingURL) {
            AppController.shared.pushChannelViewController(for: hashtag.string)
            return true
        }
        
        return false
    }

}
