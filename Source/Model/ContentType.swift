//
//  ContentType.swift
//  FBTT
//
//  Created by Christoph on 4/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

enum ContentType: String, CaseIterable, Codable {

    case address
    case about
    case contact
    case dropContentRequest = "drop-content-request"
    case post
    case pub
    case vote
    case blog
    case gathering

    // known but unhandled
    //    case position                         // these are poll-votes (think doodle or _what kind of pizza do you like_)
    // very nerdy dev stuff
    //    case npmPackages = "npm-packages"
    //    case gitRepo = "git-repo"
    //    case gitUpdate = "git-update"

    case unsupported

    // TODO https://app.asana.com/0/0/1108082973890863/f
    // TODO should this be encrypted vs unknown?
    // these are not unsupported but can be safely ignored by sorting/indexing
    // this should make it easier to extend support
    // without having to reconsider these in the process.
    case unknown = "xxx-encrypted"
}

/// Required protocol to allow a model to be encoding for `API.publish()`.
/// Any new models that need to be published MUST inherit this protocol.
protocol ContentTypeable {
    var type: ContentType { get }
}
