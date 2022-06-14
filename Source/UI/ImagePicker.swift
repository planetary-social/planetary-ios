//
//  ImagePicker.swift
//  FBTT
//
//  Created by Christoph on 7/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import AVKit
import Foundation
import Photos
import UIKit
import Analytics

class ImagePicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // presenting view controller has to be weak in case the
    // owner of this instance is also the view controller presenting
    private weak var presentingViewController: UIViewController? = AppController.shared
    private var selfieMode = false
    private var completion: ((UIImage?) -> Void)?
    private var controller: UIImagePickerController?

    // MARK: Presentation

    func present(from view: AnyObject,
                 controller: UIViewController? = nil,
                 openCameraInSelfieMode: Bool = false,
                 completion: @escaping ((UIImage?) -> Void)) {
        if let controller = controller { self.presentingViewController = controller }
        self.selfieMode = openCameraInSelfieMode
        self.completion = completion
        self.promptForPhotoLibraryOrCamera(from: view)
    }

    func dismiss(completion: (() -> Void)? = nil) {
        self.controller?.dismiss(animated: true, completion: completion)
    }

    // MARK: Prompting for source or to open Settings

    private func promptForPhotoLibraryOrCamera(from sourceView: AnyObject) {

        let library = UIAlertAction(title: Text.ImagePicker.selectFrom.text, style: .default) {
            [weak self] _ in
            Analytics.shared.trackDidSelectAction(actionName: "photo_library")
            self?.openPhotoLibrary()
        }

        let camera = UIAlertAction(title: Text.ImagePicker.takePhoto.text, style: .default) {
            [weak self] _ in
            Analytics.shared.trackDidSelectAction(actionName: "camera")
            self?.openCamera()
        }

        let cancel = UIAlertAction(title: Text.cancel.text, style: .cancel) { _ in
            Analytics.shared.trackDidSelectAction(actionName: "cancel")
        }

        self.presentingViewController?.choose(from: [library, camera, cancel], sourceView: sourceView)
    }

    private func promptToOpenSettings(for title: String) {
        self.presentingViewController?.confirm(
            title: Text.ImagePicker.permissionsRequired.text(["title": title]),
            message: Text.ImagePicker.openSettingsMessage.text,
            isDestructive: false,
            confirmTitle: Text.settings.text,
            confirmClosure: AppController.shared.openOSSettings
        )
    }

    // MARK: Presenting the UIImagePickerController

    private func openPhotoLibrary() {

        // denied
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .denied || status == .restricted {
            self.promptToOpenSettings(for: Text.ImagePicker.photoLibrary.text)
            return
        }

        // allowed
        if status == .authorized {
            self.presentImagePickerController(for: .photoLibrary)
            return
        }

        // unknown
        PHPhotoLibrary.requestAuthorization {
            [weak self] status in
            guard status == .authorized else { return }
            self?.presentImagePickerController(for: .photoLibrary)
        }
    }

    private func openCamera() {

        // simulator
        if UIDevice.isSimulator {
            self.presentingViewController?.alert(message: Text.ImagePicker.cameraNotAvailable.text,
                                                 cancelTitle: Text.ok.text)
            return
        }

        // denied
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            self.promptToOpenSettings(for: Text.ImagePicker.camera.text)
            return
        }

        // allowed
        if status == .authorized {
            self.presentImagePickerController(for: .camera)
            return
        }

        // unknown
        AVCaptureDevice.requestAccess(for: .video) {
            [weak self] allowed in
            guard allowed else { return }
            self?.presentImagePickerController(for: .camera)
        }
    }

    private func presentImagePickerController(for type: UIImagePickerController.SourceType) {
        DispatchQueue.main.async {
            self._presentImagePickerController(for: type)
        }
    }

    private func _presentImagePickerController(for type: UIImagePickerController.SourceType) {

        Thread.assertIsMainThread()

        // either source must be available
        let library = UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        let camera = UIImagePickerController.isSourceTypeAvailable(.camera)
        guard library || camera else { return }

        // present OS image picker
        // source type must be set before other options
        let controller = UIImagePickerController()
//        controller.allowsEditing = true
        controller.delegate = self
        controller.sourceType = type
        if type == .camera && self.selfieMode { controller.cameraDevice = .front }
        self.presentingViewController?.present(controller, animated: true)
        self.controller = controller
    }

    // TODO https://app.asana.com/0/914798787098068/1140073710407980/f
    // TODO replace with another framework that does not have a crop rect bug
    // TODO checking for a non-zero origin for the crop rect only works partially
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        Analytics.shared.trackDidTapButton(buttonName: "choose")
        let rect = (info[UIImagePickerController.InfoKey.cropRect] as? CGRect) ?? CGRect.zero
        let original = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        let edited = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
        let image = rect.originLikelyWasChanged() ? edited : original
        self.completion?(image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        Analytics.shared.trackDidTapButton(buttonName: "cancel")
        self.dismiss()
    }
}

fileprivate extension CGRect {

    func originLikelyWasChanged() -> Bool {
        self.origin.x != 0 || self.origin.y != 0
    }
}
