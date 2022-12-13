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
import Combine

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
    
    var images: [UIImage] {
        galleryView.images
    }

    private lazy var buttonsView: PostButtonsView = {
        let view = PostButtonsView()
        Layout.addSeparator(toTopOf: view)
        view.backgroundColor = .cardBackground
        return view
    }()

    private let imagePicker = UIImagePicker()
    
    private let draftStore: DraftStore
    private let draftKey: String
    private let queue = DispatchQueue.global(qos: .userInitiated)
    private var cancellables = [AnyCancellable]()

    // MARK: Lifecycle

    init(images: [UIImage] = []) {
        self.draftKey = "com.planetary.ios-scuttlego.draft." + (Bots.current.identity ?? "")
        self.draftStore = DraftStore(draftKey: draftKey)
        super.init(scrollable: false, title: .newPost)
        isKeyboardHandlingEnabled = true
        view.backgroundColor = .cardBackground
        addActions()
        setupDrafts()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let item = UIBarButtonItem(
            image: UIImage.verse.dismiss,
            style: .plain,
            target: self,
            action: #selector(dismissWithoutPost)
        )
        item.tintColor = .secondaryAction
        item.accessibilityLabel = Localized.done.text
        self.navigationItem.leftBarButtonItem = item
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    
    // MARK: - Drafts
    
    /// Configures the view to save and load draft posts from NSUserDefaults.
    private func setupDrafts() {
        Task {
            if let draft = await draftStore.loadDraft() {
                if let text = draft.attributedText {
                    textView.attributedText = text
                }
                galleryView.add(draft.images)
                Log.info("Restored draft")
            }
            
            textView
                .textPublisher
                .throttle(for: 3, scheduler: queue, latest: true)
                .sink { [weak self] newText in
                    let newTextValue = newText.map { AttributedString($0) }
                    Task(priority: .userInitiated) {
                        await self?.draftStore.save(text: newTextValue, images: self?.images ?? [])
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    // MARK: Actions

    private func addActions() {
        self.buttonsView.photoButton.addTarget(self, action: #selector(photoButtonTouchUpInside), for: .touchUpInside)
        self.buttonsView.previewToggle.addTarget(self, action: #selector(previewToggled), for: .valueChanged)
        self.buttonsView.postButton.action = didPressPostButton
    }

    @objc
    private func photoButtonTouchUpInside(sender: AnyObject) {
        
        Analytics.shared.trackDidTapButton(buttonName: "attach_photo")
        self.imagePicker.present(from: sender, controller: self) { [weak self] image in
            if let image = image { self?.galleryView.add(image) }
            self?.imagePicker.dismiss()
        }
    }

    @objc
    private func previewToggled() {
        Analytics.shared.trackDidTapButton(buttonName: "preview")
        self.textView.previewActive = self.buttonsView.previewToggle.isOn
    }

    func didPressPostButton(sender: AnyObject) {
        self.lookBusy(message: Localized.NewPost.publishing)
        Analytics.shared.trackDidTapButton(buttonName: "post")
        self.buttonsView.postButton.isHidden = true
        
        let hasText = self.textView.attributedText.length > 0
        let hasImages = !self.galleryView.images.isEmpty
        
        guard hasText || hasImages else {
            self.lookReady()
            return
        }
        
        let text = self.textView.attributedText
        let post = Post(attributedText: text)
        let images = self.galleryView.images

        let draftStore = draftStore
        let textValue = AttributedString(text)
        Task.detached(priority: .userInitiated) {
            await draftStore.save(text: textValue, images: self.galleryView.images)
            do {
                _ = try await Bots.current.publish(post, with: images)
                Analytics.shared.trackDidPost()
                await self.dismiss(didPublish: post)
                try StoreReviewController.promptIfConditionsMet()
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await self.alert(error: error)
            }
            await self.lookReady()
        }
    }

    private func dismiss(didPublish post: Post) async {
        // Clear UI buffers so they don't get saved as a draft on dismiss
        textView.clear()
        galleryView.removeAll()
        await self.draftStore.clearDraft()
        self.didPublish?(post)
        self.dismiss(animated: true)
    }
    
    @objc
    private func dismissWithoutPost() {
        let textValue = AttributedString(self.textView.attributedText)
        Task.detached(priority: .userInitiated) {
            await self.draftStore.save(text: textValue, images: self.images)
        }
        self.dismiss(animated: true)
    }

    // MARK: Animations

    private func lookBusy(message: Localizable? = nil) {
        AppController.shared.showProgress(after: 0.2, statusText: message?.text)
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
        let textValue = AttributedString(textView.attributedText)
        Task.detached(priority: .userInitiated) {
            await self.draftStore.save(text: textValue, images: view.images)
        }
    }

    func imageGalleryView(
        _ view: ImageGalleryView,
        didSelect image: UIImage,
        at indexPath: IndexPath
    ) {
        self.confirm(
            message: Localized.NewPost.confirmRemove.text,
            isDestructive: true,
            confirmTitle: Localized.NewPost.remove.text,
            confirmClosure: { view.remove(at: indexPath) }
        )
    }
}

extension NewPostViewController: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        let hasText = self.textView.attributedText.length > 0
        let hasImages = !self.galleryView.images.isEmpty

        if hasText || hasImages {
            let textValue = AttributedString(textView.attributedText)
            Task.detached(priority: .userInitiated) {
                await self.draftStore.save(text: textValue, images: self.images)
            }
        }
    }
}
