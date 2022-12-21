//
//  MIMEType.swift
//  FBTT
//
//  Created by Christoph on 5/8/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// swiftlint:disable identifier_name
enum MIMEType: String {
    case jpeg, jpg = "image/jpeg"
    case gif = "image/gif"
    case json = "application/json"
    case png = "image/png"
    case octetStream = "application/octet-stream"
    case mpeg, mp3 = "audio/mpeg"
    case aac = "audio/aac"
    case unknown = "unknown"
}
