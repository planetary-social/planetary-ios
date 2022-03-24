//
//  PreloadedBlobService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 3/24/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// A service class that copies blobs from a `Bundle` into a `Bot`.
protocol PreloadedBlobsService {
    /// Copies blobs into the Bot's database. The Bundle needs to have a certain structure, in practice it's the
    /// structure of Preload.bundle in this repository.
    static func preloadBlobs(into bot: Bot, from path: String, in bundle: Bundle, completion: (() -> Void)?)
}

class PreloadedBlobsServiceAdapter: PreloadedBlobsService {
    
    // This function was refactored out of `LoadBundleOperation.swift`.
    class func preloadBlobs(into bot: Bot, from path: String, in bundle: Bundle, completion: (() -> Void)? = nil) {
        let group = DispatchGroup()

        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let blobIdentifiersPath = bundle.path(
                forResource: "BlobIdentifiers",
                ofType: "plist",
                inDirectory: "Pubs"
            ),
            let xml = FileManager.default.contents(atPath: blobIdentifiersPath),
            let blobIdentifiers = try? PropertyListSerialization.propertyList(
                from: xml,
                options: .mutableContainersAndLeaves,
                format: &format
            ) as? [String: String] else {
            
                Log.error("Could not parse BlobIdentifiers.plist")
                return
        }
        
        let blobPaths  = bundle.paths(forResourcesOfType: nil, inDirectory: "Pubs/Blobs")
        blobPaths.forEach { path in
            group.enter()
            let url = URL(fileURLWithPath: path)
            guard let identifier = blobIdentifiers[url.lastPathComponent] else {
                Log.error("Couldn't find blob with identifier \(url.lastPathComponent)")
                group.leave()
                return
            }
            
            Log.info("Preloading blob \(identifier)...")
            Bots.current.store(url: url, for: identifier) { (_, error) in
                defer { group.leave() }
                
                if let error = error as NSError? {
                    if error.domain == NSCocoaErrorDomain,
                       error.code == 516 {
                        // The blob is already there, this is expected to happen most of the time.
                        return
                    }
                    Log.info("Preloading blob \(identifier) failed with error: \(error.localizedDescription).")
                } else {
                    Log.info("Blob \(identifier) was preloaded successfully.")
                }
            }
        }
        
        group.wait()
        
        completion?()
    }
}
