//
//  NewPostViewController.swift
//  FBTT
//
//  Created by Christoph on 3/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

class NewPostViewController: ContentViewController {

    var didPublish: ((Post) -> Void)?

    private lazy var textView = PostTextEditorView()

    // this view manages it's own height constraints
    // checkout ImageGallery.open() and close()
    private lazy var galleryView: ImageGalleryView = {
        let view = ImageGalleryView(height: 75)
        view.delegate = self
        view.backgroundColor = .cardBackground
        return view
    }()

    private lazy var buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        Layout.addSeparator(toTopOf: view)
        view.backgroundColor = .cardBackground
        return view
    }()

    private let imagePicker = ImagePicker()

    // MARK: Lifecycle

    init(images: [UIImage] = []) {
        super.init(scrollable: false, title: .newPost)
        self.isKeyboardHandlingEnabled = true
        self.view.backgroundColor = .cardBackground
        self.addActions()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item = UIBarButtonItem(image: UIImage.verse.dismiss,
                                   style: .plain,
                                   target: self,
                                   action: #selector(dismissWithoutPost))
        item.tintColor = .secondaryAction
        item.accessibilityLabel = Text.done.text
        self.navigationItem.leftBarButtonItem = item
        
        if let draft = Draft.current {
            self.textView.attributedText = draft.attributedText
            self.galleryView.add(draft.images)
            print("Restored draft")
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        self.parent?.presentationController?.delegate = self
    }

    override func constrainSubviews() {
        super.constrainSubviews()

        Layout.fillTop(of: self.contentView, with: self.textView)

        Layout.fillSouth(of: self.textView, with: self.galleryView)

        Layout.fillBottom(of: self.contentView, with: self.buttonsView, respectSafeArea: false)
        self.buttonsView.pinTop(toBottomOf: self.galleryView)
        self.buttonsView.constrainHeight(to: PostButtonsView.viewHeight)
    }

    // MARK: Actions

    private func addActions() {
        self.buttonsView.photoButton.addTarget(self, action: #selector(photoButtonTouchUpInside), for: .touchUpInside)
        self.buttonsView.previewToggle.addTarget(self, action: #selector(previewToggled), for: .valueChanged)
        self.buttonsView.postButton.action = didPressPostButton
    }

    @objc private func photoButtonTouchUpInside(sender: AnyObject) {
        
        Analytics.shared.trackDidTapButton(buttonName: "attach_photo")
        self.imagePicker.present(from: sender, controller: self) {
            [weak self] image in
            if let image = image { self?.galleryView.add(image) }
            self?.imagePicker.dismiss()
        }
    }

    @objc private func previewToggled() {
        Analytics.shared.trackDidTapButton(buttonName: "preview")
        self.textView.previewActive = self.buttonsView.previewToggle.isOn
    }

    func didPressPostButton(sender: AnyObject) {
        Analytics.shared.trackDidTapButton(buttonName: "post")
        self.buttonsView.postButton.isHidden = true
        
        let hasText = self.textView.attributedText.length > 0
        let hasImages = !self.galleryView.images.isEmpty
        
        guard hasText || hasImages else {
            return
        }
        
        let text = self.textView.attributedText
        let post = Post(attributedText: text)
        let images = self.galleryView.images

        self.lookBusy()
        Bots.current.publish(post, with: images) {
            [weak self] _, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                self?.alert(error: error)
            } else {
                Analytics.shared.trackDidPost()
                self?.dismiss(didPublish: post)
            }
            self?.lookReady()
        }
    }

    private func dismiss(didPublish post: Post) {
        Draft.current = nil
        self.didPublish?(post)
        self.dismiss(animated: true)
    }
    
    @objc private func dismissWithoutPost() {
        Draft.current = nil
        self.dismiss(animated: true)
    }

    // MARK: Animations

    private func lookBusy() {
        AppController.shared.showProgress()
        self.buttonsView.photoButton.isEnabled = false
        self.buttonsView.postButton.isEnabled = false
        self.buttonsView.previewToggle.isEnabled = false
        self.buttonsView.postButton.isHidden = true
    }

    private func lookReady() {
        AppController.shared.hideProgress()
        self.buttonsView.photoButton.isEnabled = true
        self.buttonsView.postButton.isEnabled = true
        self.buttonsView.postButton.isHidden = false
        self.buttonsView.previewToggle.isEnabled = true
    }   
}

extension NewPostViewController: ImageGalleryViewDelegate {

    // Limits the max number of images to 8
    func imageGalleryViewDidChange(_ view: ImageGalleryView) {
        self.buttonsView.photoButton.isEnabled = view.images.count < 8
        view.images.isEmpty ? view.close() : view.open()
    }

    func imageGalleryView(_ view: ImageGalleryView,
                          didSelect image: UIImage,
                          at indexPath: IndexPath) {
        self.confirm(
            message: Text.NewPost.confirmRemove.text,
            isDestructive: true,
            confirmTitle: Text.NewPost.remove.text,
            confirmClosure: { view.remove(at: indexPath) }
        )
    }
}

extension NewPostViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("didDIsmisssss")
        
        let hasText = self.textView.attributedText.length > 0
        let hasImages = !self.galleryView.images.isEmpty

        if hasText || hasImages {
            Draft.current = Draft(attributedText: self.textView.attributedText, images: self.galleryView.images)
            print("Saved draft")
        }
    }
}
