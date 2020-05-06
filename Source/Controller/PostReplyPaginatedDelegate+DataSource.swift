//
//  PostReplyPaginatedDelegate+DataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit

protocol PostReplyPaginatedDataSourceDelegate: class {
    
    func postReplyView(view: PostReplyView, didLoad keyValue: KeyValue)
    
}

class PostReplyPaginatedDataSource: KeyValuePaginatedTableViewDataSource {
    
    weak var delegate: PostReplyPaginatedDataSourceDelegate?
    
    override func cell(at indexPath: IndexPath, for type: ContentType) -> KeyValueTableViewCell {
        let view = PostReplyView()
        view.postView.truncationLimit = self.truncationLimitForPost(at: indexPath)
        let cell = KeyValueTableViewCell(for: .post, with: view)
        return cell
    }
    
    private func truncationLimitForPost(at indexPath: IndexPath) -> TruncationSettings? {
        guard let keyValue = self.data.keyValueBy(index: indexPath.row, late: noop) else { return nil }
        guard let post = keyValue.value.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
    
    override func loadKeyValue(_ keyValue: KeyValue, in cell: KeyValueTableViewCell) {
        super.loadKeyValue(keyValue, in: cell)
        if let postReplyView = cell.keyValueView as? PostReplyView {
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
        return PostReplyView.estimatedHeight(with: keyValue, in: tableView)
    }
    
    override func viewController(for keyValue: KeyValue) -> UIViewController? {
        return ThreadViewController(with: keyValue, startReplying: false)
    }
    
}
