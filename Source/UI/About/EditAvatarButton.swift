//
//  EditAvatarButton.swift
//  Planetary
//
//  Created by Martin Dutra on 21/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Photos
import Logger
import SwiftUI

struct EditAvatarButton: View {

    var about: About?
    var large: Bool

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var isEditingAvatar = false

    @State
    private var imagePickerSourceType: UIImagePickerController.SourceType?

    private var showImagePicker: Binding<Bool> {
        Binding {
            imagePickerSourceType != nil
        } set: { _ in
            imagePickerSourceType = nil
        }
    }

    @State
    private var settingsAlertTitle: String?

    private var showSettingsAlert: Binding<Bool> {
        Binding {
            settingsAlertTitle != nil
        } set: { _ in
            settingsAlertTitle = nil
        }
    }

    @State
    var alertMessage: String?

    private var showAlert: Binding<Bool> {
        Binding {
            alertMessage != nil
        } set: { _ in
            alertMessage = nil
        }
    }

    private var size: CGFloat {
        large ? 15 : 10
    }

    private var padding: CGFloat {
        large ? 5 : 3
    }

    var body: some View {
        Button {
            isEditingAvatar = true
        } label: {
            ZStack {
                Image.navIconCamera
                    .resizable()
                    .frame(width: size, height: size)
            }
            .padding(EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding))
            .background(Circle().fill(LinearGradient.diagonalAccent))
        }
        .confirmationDialog("", isPresented: $isEditingAvatar) {
            Button(Localized.ImagePicker.selectFrom.text) {
                Analytics.shared.trackDidSelectAction(actionName: "photo_library")
                openPhotoLibrary()
            }
            Button(Localized.ImagePicker.takePhoto.text) {
                Analytics.shared.trackDidSelectAction(actionName: "camera")
                openCamera()
            }
            Button(Localized.cancel.text, role: .cancel) {
                Analytics.shared.trackDidSelectAction(actionName: "cancel")
                isEditingAvatar = false
            }
        }
        .alert(
            settingsAlertTitle ?? "",
            isPresented: showSettingsAlert,
            actions: {
                Button(Localized.settings.text) {
                    AppController.shared.openOSSettings()
                }
                Button(Localized.cancel.text, role: .cancel) {
                    settingsAlertTitle = nil
                }
            },
            message: {
                Text(Localized.ImagePicker.openSettingsMessage.text)
            }
        )
        .sheet(isPresented: showImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType ?? .camera) { image in
                guard let image = image else {
                    imagePickerSourceType = nil
                    isEditingAvatar = false
                    return
                }
                publishProfilePhoto(image) { error in
                    guard error == nil else {
                        Log.optional(error)
                        CrashReporting.shared.reportIfNeeded(error: error)
                        alertMessage = error?.localizedDescription
                        return
                    }
                    imagePickerSourceType = nil
                    isEditingAvatar = false
                }
            }
            .alert(
                Localized.error.text,
                isPresented: showAlert,
                actions: {
                    Button(Localized.ok.text) {
                        alertMessage = nil
                    }
                },
                message: {
                    Text(alertMessage ?? "")
                }
            )
        }
    }

    private func promptToOpenSettings(for title: String) {
        settingsAlertTitle = Localized.ImagePicker.permissionsRequired.text(["title": title])
    }

    private func presentImagePickerController(for type: UIImagePickerController.SourceType) {
        imagePickerSourceType = type
    }

    private func openPhotoLibrary() {
        // denied
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .denied || status == .restricted {
            promptToOpenSettings(for: Localized.ImagePicker.photoLibrary.text)
            return
        }

        // allowed
        if status == .authorized {
            presentImagePickerController(for: .photoLibrary)
            return
        }

        // unknown
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                return
            }
            Task {
                await MainActor.run {
                    presentImagePickerController(for: .photoLibrary)
                }
            }
        }
    }

    private func openCamera() {
        // denied
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            self.promptToOpenSettings(for: Localized.ImagePicker.camera.text)
            return
        }

        // allowed
        if status == .authorized {
            self.presentImagePickerController(for: .camera)
            return
        }

        // unknown
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            guard allowed else {
                return
            }
            Task {
                await MainActor.run {
                    presentImagePickerController(for: .camera)
                }
            }
        }
    }

    private func publishProfilePhoto(_ uiimage: UIImage, completionHandler: @escaping (Error?) -> Void) {
        Bots.current.addBlob(jpegOf: uiimage, largestDimension: 1000) { image, error in
            if let error = error {
                completionHandler(error)
                return
            }

            guard let about = about?.mutatedCopy(image: image) else {
                // I don't see why this should ever happen
                // But will leave as it is
                let error = AppError.unexpected
                completionHandler(error)
                return
            }
            Task.detached {
                let bot = await botRepository.current
                do {
                    try await bot.publish(content: about)
                    Analytics.shared.trackDidUpdateAvatar()
                    if let about = try await bot.about() {
                        await MainActor.run {
                            NotificationCenter.default.post(Notification.didUpdateAbout(about))
                        }
                        completionHandler(nil)
                    }
                } catch {
                    completionHandler(error)
                }
            }
        }
    }
}
