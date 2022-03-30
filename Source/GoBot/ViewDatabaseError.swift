//
//  ViewDatabaseError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum ViewDatabaseError: Error {
    case notOpen
    case alreadyOpen
    case unknownMessage(MessageIdentifier)
    case unknownAuthor(Identifier)
    case unknownHashtag(String)
    case unknownReferenceID(Int64)
    case unexpectedContentType(String)
    case unknownTable(ViewDatabaseTableNames)
    case unhandledContentType(ContentType)
    case messageConstraintViolation(Identity, String)
}
