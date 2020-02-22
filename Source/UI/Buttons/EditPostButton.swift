//
//  EditPostButton.swift
//  Planetary
//
//  Created by Zef Houssney on 10/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

class EditPostButton: IconButton {
    let post: KeyValue

    init(post: KeyValue) {
        self.post = post
        super.init(icon: UIImage.verse.editProfileOff)
        self.highlightedImage = UIImage.verse.editProfileOn
    }

    override func defaultAction() {
        let delete = UIAlertAction(title: Text.deletePost.text, style: .destructive) { [unowned self] _ in
            AppController.shared.confirm(message: Text.confirmDeletePost.text, isDestructive: true, confirmTitle: Text.deletePost.text) {
                Bots.current.delete(message: self.post.key) { (error) in
                    if let error = error {
                        let detail = "Error deleting post: \(error)"
                        Log.unexpected(.botError, detail)
                        AppController.shared.alert(message: "Sorry, there was an error when trying to delete your post.")
                    } else {
                        // TODO: Update UI for post deletion
                        // https://app.asana.com/0/914798787098068/1114068646928290/f
                    }
                }
            }

        }

        // TODO: Reenable edit later
//        let edit = UIAlertAction(title: Text.editPost.text, style: .default) { _ in
//            AppController.shared.alert(title: "Unimplemented", message: "TODO: Implement post edit interface.", cancelTitle: Text.ok.text)
//        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in }

        AppController.shared.choose(from: [delete, cancel])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

