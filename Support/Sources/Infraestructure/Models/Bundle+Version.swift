//
//  Bundle+Version.swift
//  
//
//  Created by Martin Dutra on 28/3/22.
//

import Foundation

extension Bundle {

    var version: String {
        let version = self.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return version
    }

    var build: String {
        let build = self.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build
    }

    /// Returns a string from the bundle version and short version
    /// formatted as 1.2.3 (123).
    var versionAndBuild: String {
        return "\(self.version) (\(self.build))"
    }

}
