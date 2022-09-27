//
//  EditPostButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics
import Support
import SwiftUI

class EditPostButton: IconButton {
    let post: KeyValue

    init(post: KeyValue) {
        self.post = post
        super.init(icon: UIImage.verse.optionsOff)
        self.highlightedImage = UIImage.verse.optionsOn
    }

    override func defaultAction() {
        Analytics.shared.trackDidTapButton(buttonName: "options")
        
        let copy = UIAlertAction(title: Text.copyMessageIdentifier.text, style: .default) { [post] _ in
            Analytics.shared.trackDidSelectAction(actionName: "copy_message_identifier")
            UIPasteboard.general.string = post.key
            AppController.shared.showToast(Text.identifierCopied.text)
        }
        
        let share = UIAlertAction(title: Text.shareThisMessage.text, style: .default) { [post] _ in
            guard let publicLink = post.key.publicLink else {
                AppController.shared.alert(message: Text.Error.couldNotGenerateLink.text)
                return
            }
            Analytics.shared.trackDidSelectAction(actionName: "share_message")
            let activityController = UIActivityViewController(activityItems: [publicLink], applicationActivities: nil)
            if let popOver = activityController.popoverPresentationController {
                popOver.sourceView = self
            }
            AppController.shared.present(activityController, animated: true)
        }

        let viewSource = UIAlertAction(title: Text.viewSource.text, style: .default) { [post] _ in
            Analytics.shared.trackDidSelectAction(actionName: "view_source")
            let viewModel = RawMessageCoordinator(keyValue: post, bot: Bots.current)
            let controller = UIHostingController(rootView: RawMessageView(viewModel: viewModel))
            let navController = UINavigationController(rootViewController: controller)
            AppController.shared.present(navController, animated: true)
        }
        
        let delete = UIAlertAction(title: Text.deletePost.text, style: .destructive) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "delete_post")
            guard let controller = Support.shared.articleViewController(.editPost) else {
                AppController.shared.alert(
                    title: Text.error.text,
                    message: Text.Error.supportNotConfigured.text,
                    cancelTitle: Text.ok.text
                )
                return
            }
            let navController = UINavigationController(rootViewController: controller)
            AppController.shared.present(navController, animated: true)
        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }

        AppController.shared.choose(from: [copy, share, viewSource, delete, cancel], sourceView: self)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }
}
