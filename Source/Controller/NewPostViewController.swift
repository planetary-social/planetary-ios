//
//  NewPostViewController.swift
//  FBTT
//
//  Created by Christoph on 3/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class NewPostViewController: ContentViewController {

    var didPublish: ((Post) -> Void)?

    private let font = UIFont.systemFont(ofSize: 19, weight: .regular)
    private lazy var fontAttribute = [NSAttributedString.Key.font: self.font]

    private lazy var textView: UITextView = {
        let view = UITextView.forPostsAndReplies()
        view.backgroundColor = UIColor.background.default
        view.delegate = self.mentionDelegate
        view.font = font
        view.textColor = UIColor.text.default
        return view
    }()

    private let mentionDelegate = MentionTextViewDelegate(font: UIFont.verse.newPost,
                                                          color: UIColor.text.default)

    private lazy var menu: AboutsMenu = {
        let view = AboutsMenu()
        view.bottomSeparator.isHidden = true
        return view
    }()

    // this view manages it's own height constraints
    // checkout ImageGallery.open() and close()
    private lazy var galleryView: ImageGalleryView = {
        let view = ImageGalleryView(height: 75)
        view.delegate = self
        view.backgroundColor = UIColor.post.background
        return view
    }()

    private lazy var buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        Layout.addSeparator(toTopOf: view)
        view.backgroundColor = UIColor.post.background
        return view
    }()

    private let imagePicker = ImagePicker()

    // MARK: Lifecycle

    init(images: [UIImage] = []) {
        super.init(scrollable: false, title: .newPost)
        self.isKeyboardHandlingEnabled = true
        self.view.backgroundColor = UIColor.background.default
        self.addActions()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item = UIBarButtonItem(image: UIImage.verse.dismiss, style: .plain, target: self, action: #selector(dismissWithoutPost))
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

        Layout.fillTop(of: self.contentView, with: self.textView, insets: UIEdgeInsets.default)

        Layout.fillSouth(of: self.textView, with: self.galleryView)

        Layout.fillBottom(of: self.contentView, with: self.buttonsView, respectSafeArea: false)
        self.buttonsView.pinTop(toBottomOf: self.galleryView)
        self.buttonsView.constrainHeight(to: PostButtonsView.viewHeight)

        self.contentView.addSubview(self.menu)
        self.menu.pinBottom(toTopOf: self.buttonsView)
        self.menu.constrainWidth(to: self.buttonsView)
    }

    // MARK: Actions

    private func addActions() {

        self.mentionDelegate.didChangeMention = {
            [unowned self] string in
            self.menu.filter(by: string)
        }

        self.menu.didSelectAbout = {
            [unowned self] about in
            guard let range = self.mentionDelegate.mentionRange else { return }
            self.textView.replaceText(in: range, with: about.mention, attributes: self.fontAttribute)
            self.mentionDelegate.clear()
            self.menu.hide()
        }

        self.buttonsView.photoButton.addTarget(self, action: #selector(photoButtonTouchUpInside), for: .touchUpInside)

        self.buttonsView.postButton.action = didPressPostButton
    }

    @objc private func photoButtonTouchUpInside() {
        Analytics.shared.trackDidTapButton(buttonName: "attach_photo")
        self.imagePicker.present(from: self) {
            [weak self] image in
            if let image = image { self?.galleryView.add(image) }
            self?.imagePicker.dismiss()
        }
    }

    func didPressPostButton() {
        Analytics.shared.trackDidTapButton(buttonName: "post")

        let hasText = !self.textView.text.isEmpty
        let hasImages = !self.galleryView.images.isEmpty
        
        guard hasText || hasImages else {
            return
        }
        
        let text = self.textView.attributedText ?? NSAttributedString(string: "")
        let post = Post(attributedText: text)
        let images = self.galleryView.images

        self.lookBusy()
        Bots.current.publish(post, with: images) {
            [weak self] identifier, error in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.lookReady()
            if let error = error {
                self?.alert(error: error)
            } else {
                Analytics.shared.trackDidPost()
                self?.dismiss(didPublish: post)
            }
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
    }

    private func lookReady() {
        AppController.shared.hideProgress()
        self.buttonsView.photoButton.isEnabled = true
        self.buttonsView.postButton.isEnabled = true
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
                          at indexPath: IndexPath)
    {
        self.confirm(style: .alert,
                     message: Text.NewPost.confirmRemove.text,
                     isDestructive: true,
                     confirmTitle: Text.NewPost.remove.text,
                     confirmClosure: { view.remove(at: indexPath) })
    }
}

extension NewPostViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        print("didDIsmisssss")
        
        let hasText = !self.textView.text.isEmpty
        let hasImages = !self.galleryView.images.isEmpty

        if hasText || hasImages {
            Draft.current = Draft(attributedText: self.textView.attributedText, images: self.galleryView.images)
            print("Saved draft")
        }
    }
}
