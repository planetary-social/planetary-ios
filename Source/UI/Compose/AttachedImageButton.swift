//
//  AttachedImageButton.swift
//  Planetary
//
//  Created by Martin Dutra on 14/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct AttachedImageButton: View {

    var image: UIImage

    var onCompletion: ((UIImage) -> Void)

    @State
    private var showDeleteAttachmentConfirmation = false

    var body: some View {
        Button {
            showDeleteAttachmentConfirmation = true
        } label: {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 65, height: 65)
                Image.navIconDismiss.padding(3).background(Circle().foregroundColor(.primaryTxt.opacity(0.4)))
            }
        }
        .confirmationDialog(
            Localized.NewPost.remove.text,
            isPresented: $showDeleteAttachmentConfirmation,
            actions: {
                Button(Localized.ok.text, role: .destructive) {
                    showDeleteAttachmentConfirmation = false
                    onCompletion(image)
                }
                Button(Localized.cancel.text, role: .cancel) {
                    showDeleteAttachmentConfirmation = false
                }
            },
            message: {
                Localized.NewPost.confirmRemove.view
            }
        )
    }
}

struct AttachedImageButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AttachedImageButton(image: UIImage(named: "avatar1") ?? .gobotIcon) { image in
                print(image)
            }
            AttachedImageButton(image: UIImage(named: "avatar1") ?? .gobotIcon) { image in
                print(image)
            }
            .preferredColorScheme(.dark)
        }
    }
}
