//
//  EditIdentityButton.swift
//  Planetary
//
//  Created by Martin Dutra on 18/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct EditIdentityButton: View {

    var about: About?
    var compact = false
    
    var body: some View {
        Button {
            Analytics.shared.trackDidTapButton(buttonName: "update_profile")
            let controller = EditAboutViewController(with: about)
            controller.saveCompletion = { _ in
                Bots.current.publish(content: controller.about) { (_, error) in
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    if let error = error {
                        AppController.shared.hideProgress()
                        AppController.shared.alert(error: error)
                    } else {
                        Analytics.shared.trackDidUpdateProfile()
                        Bots.current.about { (newAbout, error) in
                            Log.optional(error)
                            CrashReporting.shared.reportIfNeeded(error: error)
                            AppController.shared.hideProgress()
                            if let newAbout = newAbout {
                                NotificationCenter.default.post(Notification.didUpdateAbout(newAbout))
                            }
                            controller.dismiss(animated: true)
                        }
                    }
                }
            }
            AppController.shared.present(UINavigationController(rootViewController: controller), animated: true)
        } label: {
            HStack(alignment: .center) {
                Image.buttonEditProfile
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                if !compact {
                    Text(Localized.editProfile.text)
                        .font(.footnote)
                        .foregroundLinearGradient(
                            LinearGradient.horizontalAccent
                        )
                }
            }
            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .background(
                LinearGradient(
                    colors: [.relationshipViewBg],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(17)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17)
                    .stroke(LinearGradient.horizontalAccent, lineWidth: 1)
            )
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

struct EditIdentityButton_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack {
                EditIdentityButton(compact: true)
                EditIdentityButton()
            }
            VStack {
                EditIdentityButton()
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
