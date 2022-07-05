//
//  LoadBundleOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 6/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

class LoadBundleOperation: AsynchronousOperation {

    var bundle: Bundle
    private(set) var error: Error?
    
    init(bundle: Bundle) {
        self.bundle = bundle
        super.init()
    }

    override func main() {
        Log.info("LoadBundleOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. LoadBundleOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        let group = DispatchGroup()
        
        let feedPaths = bundle.paths(forResourcesOfType: "json", inDirectory: "Feeds")
        feedPaths.forEach { path in
            group.enter()
            let url = URL(fileURLWithPath: path)
            Log.info("Preloading feed \(url.lastPathComponent)...")
            Bots.current.preloadFeed(at: url) { (error) in
                if let error = error {
                    Log.info("Preloading feed \(url.lastPathComponent) failed with error: \(error.localizedDescription).")
                } else {
                    Log.info("Feed \(url.lastPathComponent) was preloaded successfully.")
                }
                group.leave()
            }
        }
        
        group.enter()
        PreloadedBlobsServiceAdapter.preloadBlobs(into: Bots.current, from: ".", in: bundle) {
            group.leave()
        }
        
        group.enter()
        PreloadedBlobsServiceAdapter.preloadBlobs(into: Bots.current, from: "Pubs", in: bundle) {
            group.leave()
        }
        
        group.wait()
        self.finish()
    }
}
