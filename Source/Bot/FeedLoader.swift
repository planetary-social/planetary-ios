//
//  FeedLoader.swift
//  Planetary
//
//  Created by Rabble on 5/8/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class FeedLoader: AsynchronousOperation {

    
    var configuration: AppConfiguration
    var success: Bool = false
    var error: Error?
    
    init(configuration: AppConfiguration) {
        self.configuration = configuration
        super.init()
    }

    
    override func main() {
        Log.info("FeedLoader started.")
        //loadDefaultContent()
    }
    

    
    func loadDefaultContent(identity: Identity) {
        //let data = self.data(for: "Feed_big.json")
/*
        var urls: [URL] = []
        do {
            // get test messages from JSON
            let msgs = try JSONDecoder().decode([KeyValue].self, from: data)
            let vdb = ViewDatabase()
            let tmpURL = NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), NSUUID().uuidString])!
            try! FileManager.default.createDirectory(at: tmpURL, withIntermediateDirectories: true)

            _ = vdb.close() // close init()ed version...
            
            urls += [tmpURL] // don't litter
            
            let  damnPath = tmpURL.absoluteString.replacingOccurrences(of: "file://", with: "")
            try! vdb.open(path: damnPath, user: identity)
            
            try! vdb.fillMessages(msgs: msgs)
            
            _ = vdb.close()

        } catch {
             Log.info("FeedLoader Failed.")
        }
 */
    }

}
