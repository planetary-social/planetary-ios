//
//  PostReplyDelegate+DataSource.swift
//  Planetary
//
//  Created by Zef Houssney on 11/13/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

class PostReplyDataSource: KeyValueTableViewDataSource {

    override func cell(at indexPath: IndexPath, for type: ContentType, tableView: UITableView) -> KeyValueTableViewCell {
        let view = PostReplyView()
        view.postView.truncationLimit = self.truncationLimitForPost(at: indexPath)
        let cell = KeyValueTableViewCell(for: .post, with: view)
        return cell
    }

    private func truncationLimitForPost(at indexPath: IndexPath) -> TruncationSettings? {
        let keyValue = self.keyValue(at: indexPath)
        guard let post = keyValue.value.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
}

class PostReplyDelegate: KeyValueTableViewDelegate {

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        guard let cell = cell as? KeyValueTableViewCell else { return }
        guard let view = cell.keyValueView as? PostReplyView else { return }
        guard let keyValue = tableView.keyValue(for: indexPath) else { return }

        // open thread
        view.postView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue)
        }
        view.repliesView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "replies")
            self?.pushThreadViewController(with: keyValue)
        }

        // open thread and start reply
        view.replyTextView.tapGesture.tap = {
            [weak self] in
            Analytics.shared.trackDidSelectItem(kindName: "post", param: "area", value: "post")
            self?.pushThreadViewController(with: keyValue, startReplying: true)
        }
    }

    private func pushThreadViewController(with keyValue: KeyValue, startReplying: Bool = false) {
        let controller = ThreadViewController(with: keyValue, startReplying: startReplying)
        self.viewController?.navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dataSource = tableView.keyValueDataSource else { return tableView.bounds.size.width }
        let keyValue = dataSource.keyValues[indexPath.row]
        return PostReplyView.estimatedHeight(with: keyValue, in: tableView)
    }
}
