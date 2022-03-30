//
//  UIDevice+Simulator.swift
//  FBTT
//
//  Created by Christoph on 8/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIDevice {

    static var isSimulator: Bool {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
    }
}
