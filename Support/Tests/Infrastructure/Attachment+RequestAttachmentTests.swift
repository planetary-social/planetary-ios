//
//  File.swift
//  
//
//  Created by Martin Dutra on 1/4/22.
//

import Foundation
import XCTest
@testable import Support

class Attachment_RequestAttachmentTests: XCTestCase {

    func testRequestAttachemnt() throws {
        let data = try XCTUnwrap("hi".data(using: .utf8))
        let attachment = Attachment(
            filename: "my-filename",
            data: data,
            type: .plainText
        )
        let requestAttachment = attachment.requestAttachment
        XCTAssertEqual(requestAttachment.filename, "my-filename")
        XCTAssertEqual(requestAttachment.data, data)
        XCTAssertEqual(requestAttachment.fileType, .plain)
    }
}
