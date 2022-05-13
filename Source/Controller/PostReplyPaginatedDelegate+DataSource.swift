//
//  PostReplyPaginatedDelegate+DataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

protocol PostReplyPaginatedDataSourceDelegate: AnyObject {
    
    func postReplyView(view: PostReplyView, didLoad keyValue: KeyValue)
}

class PostReplyPaginatedDataSource: KeyValuePaginatedTableViewDataSource {
    
    weak var delegate: PostReplyPaginatedDataSourceDelegate?
    
    override func emptyCell() -> KeyValueTableViewCell {
        let view = PostReplyView()
        view.postView.truncationLimit = TruncationSettings(over: 8, to: 5)
        return KeyValueTableViewCell(for: .post, with: view)
    }
    
    override func cell(at indexPath: IndexPath, for type: ContentType) -> KeyValueTableViewCell {
        switch type {
        case .contact:
            let view = ContactReplyView()
            return KeyValueTableViewCell(for: .contact, with: view)
        default:
            let view = PostReplyView()
            view.postView.truncationLimit = self.truncationLimitForPost(at: indexPath)
            return KeyValueTableViewCell(for: .post, with: view)
        }
    }
    
    private func truncationLimitForPost(at indexPath: IndexPath) -> TruncationSettings? {
        guard let keyValue = self.data.keyValueBy(index: indexPath.row, late: noop) else {
            return TruncationSettings(over: 8, to: 5)
        }
        return truncationLimitForPost(keyValue: keyValue)
    }
    
    private func truncationLimitForPost(keyValue: KeyValue) -> TruncationSettings? {
        guard let post = keyValue.value.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
    
    override func loadKeyValue(_ keyValue: KeyValue, in cell: KeyValueTableViewCell) {
        switch keyValue.contentType {
        case .contact:
            super.loadKeyValue(keyValue, in: cell)
        default:
            guard let postReplyView = cell.keyValueView as? PostReplyView else {
                return
            }
            postReplyView.postView.truncationLimit = self.truncationLimitForPost(keyValue: keyValue)
            super.loadKeyValue(keyValue, in: cell)
            self.delegate?.postReplyView(view: postReplyView, didLoad: keyValue)
        }
    }
}

class PostReplyPaginatedDelegate: KeyValuePaginatedTableViewDelegate {

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dataSource = tableView.dataSource as? KeyValuePaginatedTableViewDataSource else {
            return tableView.bounds.size.width
        }
        guard let keyValue = dataSource.data.keyValueBy(index: indexPath.row) else {
            return tableView.bounds.size.width
        }
        switch keyValue.contentType {
        case .contact:
            return ContactReplyView.estimatedHeight(with: keyValue, in: tableView)
        default:
            return PostReplyView.estimatedHeight(with: keyValue, in: tableView)
        }
    }
    
    override func viewController(for keyValue: KeyValue) -> UIViewController? {
        switch keyValue.contentType {
        case .contact:
            guard let identity = keyValue.value.content.contact?.identity else {
                return nil
            }
            return AboutViewController(with: identity)
        default:
            return ThreadViewController(with: keyValue, startReplying: false)
        }
    }
}
