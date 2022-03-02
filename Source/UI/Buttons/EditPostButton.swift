//
//  EditPostButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit
import Analytics

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
            guard let publicLink = post.key.publicLink, let me = Bots.current.about else {
                return
            }
            let who = me.name ?? me.identity
            let link = publicLink.absoluteString
            let postWithoutGallery = post.value.content.post?.text.withoutGallery() ?? ""
            let what = postWithoutGallery.prefix(280 - who.count - link.count - Text.shareThisMessageText.text.count)
            let text = Text.shareThisMessageText.text(["who": who,
                                                       "what": String(what),
                                                       "link": publicLink.absoluteString])
            Analytics.shared.trackDidSelectAction(actionName: "share_message")
            let activityController = UIActivityViewController(activityItems: [text],
                                                              applicationActivities: nil)
            AppController.shared.present(activityController, animated: true)
            if let popOver = activityController.popoverPresentationController {
                popOver.sourceView = self
            }
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
            let nc = UINavigationController(rootViewController: controller)
            AppController.shared.present(nc, animated: true)
        }

        // TODO: Reenable edit later
//        let edit = UIAlertAction(title: Text.editPost.text, style: .default) { _ in
//            AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement post edit interface.", cancelTitle: Text.ok.text)
//        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }

        AppController.shared.choose(from: [copy, share, delete, cancel], sourceView: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

