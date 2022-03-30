//
//  Bundle+Current.swift
//  FBTT
//
//  Created by Christoph on 1/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

private class CurrentBundle {}

extension Bundle {

    static let current = Bundle(for: CurrentBundle.self)
}
