//
//  UIDevice+Localhost.swift
//  FBTT
//
//  Created by Christoph on 1/7/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIDevice {

    /// The concept of localhost is different when the app is
    /// run in the simulator vs on device.  127.0.0.1 will not
    /// work on device, the active network interface is required
    /// so this is provided as a convenience.
    /// https://stackoverflow.com/questions/34814645/could-not-connect-to-local-server-in-xcode
    func localhost() -> String {
        #if targetEnvironment(simulator)
            return "127.0.0.1"
        #else
            return UIDevice.current.ipAddress() ?? "unknown"
        #endif
    }

    func ipAddress() -> String? {

        var address: String?

        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        freeifaddrs(ifaddr)
        return address
    }
}
