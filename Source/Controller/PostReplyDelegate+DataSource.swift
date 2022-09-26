//
//  PostReplyDelegate+DataSource.swift
//  Planetary
//
//  Created by Zef Houssney on 11/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class PostReplyDataSource: MessageTableViewDataSource {

    override func cell(at indexPath: IndexPath, for type: ContentType, tableView: UITableView) -> MessageTableViewCell {
        switch type {
        case .contact:
            let view = ContactReplyView()
            return MessageTableViewCell(for: .contact, with: view)
        default:
            let view = PostReplyView()
            view.postView.truncationLimit = self.truncationLimitForPost(at: indexPath)
            return MessageTableViewCell(for: .post, with: view)
        }
    }

    private func truncationLimitForPost(at indexPath: IndexPath) -> TruncationSettings? {
        let message = self.message(at: indexPath)
        guard let post = message.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
}

class PostReplyDelegate: MessageTableViewDelegate {

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        guard let cell = cell as? MessageTableViewCell else { return }
        guard let view = cell.messageView as? PostReplyView else { return }
        guard let message = tableView.message(for: indexPath) else { return }

        // open thread
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: message)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: message)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: message, startReplying: true)
        }
    }

    private func pushThreadViewController(with message: Message, startReplying: Bool = false) {
        let controller = ThreadViewController(with: message, startReplying: startReplying)
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dataSource = tableView.messageDataSource else { return tableView.bounds.size.width }
        let message = dataSource.messages[indexPath.row]
        switch message.contentType {
        case .contact:
            return ContactReplyView.estimatedHeight(with: message, in: tableView)
        default:
            return PostReplyView.estimatedHeight(with: message, in: tableView)
        }
    }
}
