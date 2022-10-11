//
//  PostReplyPaginatedDelegate+DataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import UIKit
import SwiftUI

protocol PostReplyPaginatedDataSourceDelegate: AnyObject {
    
    func postReplyView(view: PostReplyView, didLoad message: Message)
}

class PostReplyPaginatedDataSource: MessagePaginatedTableViewDataSource {
    
    weak var delegate: PostReplyPaginatedDataSourceDelegate?
    
    override func emptyCell() -> MessageTableViewCell {
        let view = PostReplyView()
        view.postView.truncationLimit = TruncationSettings(over: 8, to: 5)
        return MessageTableViewCell(for: .post, with: view)
    }
    
    override func cell(at indexPath: IndexPath, for type: ContentType) -> MessageTableViewCell {
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
        guard let message = self.data.messageBy(index: indexPath.row, late: noop) else {
            return TruncationSettings(over: 8, to: 5)
        }
        return truncationLimitForPost(message: message)
    }
    
    private func truncationLimitForPost(message: Message) -> TruncationSettings? {
        guard let post = message.content.post else { return nil }
        let settings: TruncationSettings = post.hasBlobs ? (over: 8, to: 5) : (over: 10, to: 8)
        return settings
    }
    
    override func loadMessage(_ message: Message, in cell: MessageTableViewCell) {
        switch message.contentType {
        case .contact:
            super.loadMessage(message, in: cell)
        default:
            guard let postReplyView = cell.messageView as? PostReplyView else {
                return
            }
            postReplyView.postView.truncationLimit = self.truncationLimitForPost(message: message)
            super.loadMessage(message, in: cell)
            self.delegate?.postReplyView(view: postReplyView, didLoad: message)
        }
    }
}

class PostReplyPaginatedDelegate: MessagePaginatedTableViewDelegate {

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dataSource = tableView.dataSource as? MessagePaginatedTableViewDataSource else {
            return tableView.bounds.size.width
        }
        guard let message = dataSource.data.messageBy(index: indexPath.row) else {
            return tableView.bounds.size.width
        }
        switch message.contentType {
        case .contact:
            return ContactReplyView.estimatedHeight(with: message, in: tableView)
        default:
            return PostReplyView.estimatedHeight(with: message, in: tableView)
        }
    }
    
    override func viewController(for message: Message) -> UIViewController? {
        switch message.contentType {
        case .contact:
            guard let identity = message.content.contact?.identity else {
                return nil
            }
            let view = IdentityView(viewModel: IdentityCoordinator(identity: identity, bot: Bots.current))
            let controller = UIHostingController(rootView: view)
            return controller
        case .vote:
            return nil
        default:
            return ThreadViewController(with: message, startReplying: false)
        }
    }
}
