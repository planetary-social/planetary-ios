//
//  DebugPostsViewController.swift
//  FBTT
//
//  Created by Christoph on 8/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DebugPostsViewController: ContentViewController {

    private let dataSource = DebugPostsTableViewDataSource()
    private lazy var delegate = MessageTableViewDelegate(on: self)
    private let tableView = UITableView.forVerse()

    init() {
        super.init(scrollable: false, dynamicTitle: "Posts")
        self.tableView.dataSource = self.dataSource
        self.tableView.delegate = self.delegate
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Layout.fill(view: self.contentView, with: self.tableView, respectSafeArea: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.dataSource.messages = [Message.postMultipleImages(), Message.postSingleImage()]
        self.tableView.reloadData()
    }
}

fileprivate extension Message {

    static func postMultipleImages() -> Message {
        let string = "We\'re at #data_terra_nemo and Dominic is giving his keynote.\n\n![Dominic Talking at Data Terra Nemo](&AmeGz5CnJqvXTX7P6xGKnvCWtc6biFgKryg71swDtPg=.sha256)\n\nTesting posting a message with attachments.\n\n![rabble_foocamp_headshot.jpg](&nV+TeSZBIDQrcOO5ClvfkvQ+XCXjf7yVHF19j2Jk3xI=.sha256)\n"
        let post = Post(text: string)
        let content = Content(from: post)
        let value = MessageValue(
            author: Environment.PlanetarySystem.systemPubs.first!.feed,
            content: content,
            hash: "",
            previous: nil,
            sequence: 0,
            signature: Identifier.null,
            claimedTimestamp: Date().millisecondsSince1970
        )
        let message = Message(key: Identifier.null, value: value, timestamp: 0)
        return message
    }

    static func postSingleImage() -> Message {
        let string = "Testing posting a message with attachments.\n\n![rabble_foocamp_headshot.jpg](&nV+TeSZBIDQrcOO5ClvfkvQ+XCXjf7yVHF19j2Jk3xI=.sha256)\n\n"
        let post = Post(text: string)
        let content = Content(from: post)
        let value = MessageValue(
            author: "@njMfLnYyzBoKsaESjIK6UZLa9Ky0+PkUJz7Mi4ri8Mg=.ed25519",
            content: content,
            hash: "sha256",
            previous: nil,
            sequence: 234,
            signature: "verified_by_go-ssb",
            claimedTimestamp: Date().millisecondsSince1970
        )
        let message = Message(key: Identifier.null, value: value, timestamp: 0)
        return message
    }
}

private class DebugPostsTableViewDataSource: MessageTableViewDataSource {

    override func cell(at indexPath: IndexPath,
                       for type: ContentType,
                       tableView: UITableView) -> MessageTableViewCell {
        let view = PostReplyView()
        let cell = MessageTableViewCell(for: .post, with: view)
        return cell
    }
}
