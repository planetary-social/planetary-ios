//
//  ImagePicker.swift
//  Planetary
//
//  Created by Martin Dutra on 21/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    var onCompletion: ((UIImage?) -> Void)

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        if sourceType == .camera {
            imagePicker.cameraDevice = .front
        }
        return imagePicker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: UIViewControllerRepresentableContext<ImagePicker>
    ) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Analytics.shared.trackDidTapButton(buttonName: "cancel")
            parent.onCompletion(nil)
        }
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            Analytics.shared.trackDidTapButton(buttonName: "choose")
            let rect = (info[UIImagePickerController.InfoKey.cropRect] as? CGRect) ?? CGRect.zero
            let original = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
            let edited = info[UIImagePickerController.InfoKey.editedImage] as? UIImage
            let image = (rect.origin.x != 0 || rect.origin.y != 0) ? edited : original
            parent.onCompletion(image)
        }
    }
}
