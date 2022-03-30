//
//  RemoteNotificationUserInfo.swift
//  Planetary
//
//  Created by Christoph on 12/19/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias RemoteNotificationUserInfo = [AnyHashable: Any]
typealias UserInfoAps = [AnyHashable: Any]
typealias UserInfoAlert = [AnyHashable: Any]

extension RemoteNotificationUserInfo {

    enum `Type`: String {
        case follow
        case mention
        case reply
        case unspecified
    }

    var type: Type {
        let string = self["type"] as? String ?? ""
        return Type(rawValue: string) ?? Type.unspecified
    }

    var rawType: String {
        self["type"] as? String ?? "could not decode type"
    }

    var isSupported: Bool {
        self.type != .unspecified
    }

    var aps: UserInfoAps {
        self["aps"] as? UserInfoAps ?? [:]
    }

    var title: String? {
        let alert = self["alert"] as? [AnyHashable: Any]
        return alert?["title"] as? String
    }

    var body: String? {
        if let body = self["alert"] as? String { return body }
        let alert = self["alert"] as? [AnyHashable: Any]
        return alert?["body"] as? String
    }
}

extension UserInfoAps {

    var isContentAvailable: Bool {
        self["content-available"] as? Bool ?? false
    }
}
