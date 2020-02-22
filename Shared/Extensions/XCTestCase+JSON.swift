//
//  XCTestCase+JSON.swift
//  FBTTUnitTests
//
//  Created by Christoph on 2/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import XCTest

extension XCTestCase {

    // Convenience func to load and return JSON resource file as Data.
    func data(for jsonResourceName: String) -> Data {
        guard let url = Bundle.current.url(forResource: jsonResourceName, withExtension: nil) else { return Data() }
        guard let data = try? Data(contentsOf: url) else { return Data() }
        return data
    }
}
