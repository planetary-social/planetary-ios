//
//  LoadBundleOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 6/3/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

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
        
        let blobIdentifiersPath = bundle.path(forResource: "BlobIdentifiers", ofType: "plist")!
        let xml = FileManager.default.contents(atPath: blobIdentifiersPath)!
        var format = PropertyListSerialization.PropertyListFormat.xml
        let blobIdentifiers = try! PropertyListSerialization.propertyList(from: xml,
                                                                          options: .mutableContainersAndLeaves,
                                                                          format: &format) as! [String: String]
        
        let blobPaths  = bundle.paths(forResourcesOfType: nil, inDirectory: "Blobs")
        blobPaths.forEach { path in
            group.enter()
            let url = URL(fileURLWithPath: path)
            let identifier = blobIdentifiers[url.lastPathComponent]!
            Log.info("Preloading blob \(identifier)...")
            Bots.current.store(url: url, for: identifier) { (_, error) in
                if let error = error {
                    Log.info("Preloading blob \(identifier) failed with error: \(error.localizedDescription).")
                } else {
                    Log.info("Blob \(identifier) was preloaded successfully.")
                }
                group.leave()
            }
        }
        
        group.wait()
        
        self.finish()
    }
    
}
