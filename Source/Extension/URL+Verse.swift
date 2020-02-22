//
//  URL+Verse.swift
//  FBTT
//
//  Created by Christoph on 7/31/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct VerseURLs {
    let support = URL(string: "https://versesupport.zendesk.com")!
}

extension URL {
    static let verse = VerseURLs()
}
