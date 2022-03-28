//
//  UIViewController+Report.swift
//  Planetary
//
//  Created by Christoph on 11/1/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Support

extension UIViewController {

    func report(_ post: KeyValue,
                in view: UIView? = nil,
                from reporter: Identity) {
        var actions: [UIAlertAction] = []
        for reason in SupportReason.allCases {
            let action = UIAlertAction(title: reason.string, style: .default) {
                [weak self] _ in
                self?.report(post, in: view, reason: reason, from: reporter)
            }
            actions += [action]
        }

        actions += [UIAlertAction.cancel()]

        AppController.shared.choose(from: actions,
                                    title: Text.Reporting.whyAreYouReportingThisPost.text)
    }

    private func report(_ post: KeyValue,
                        in view: UIView? = nil,
                        reason: SupportReason,
                        from reporter: Identity) {
        let controller = Support.shared.newTicketViewController(
            from: reporter,
            reporting: post.key,
            authorRef: post.metadata.author.about?.identity,
            authorName: post.metadata.author.about?.name,
            reason: reason,
            view: view
        )
        guard let controller = controller else {
            AppController.shared.alert(
                title: Text.error.text,
                message: Text.Error.supportNotConfigured.text,
                cancelTitle: Text.ok.text
            )
            return
        }
        AppController.shared.push(controller)
    }
}
