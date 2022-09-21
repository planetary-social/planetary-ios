//
//  RawMessageCoordinator.swift
//  Planetary
//
//  Created by Martin Dutra on 19/9/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// A coordinator for the `RawMessageView`
@MainActor class RawMessageCoordinator: RawMessageViewModel {

    private var keyValue: KeyValue

    private var bot: Bot

    @Published var rawMessage: String?
    
    @Published var loadingMessage: String?

    @Published var errorMessage: String?

    init(keyValue: KeyValue, bot: Bot) {
        self.keyValue = keyValue
        self.bot = bot
        loadRawMessage()
    }

    func didDismiss() {
        AppController.shared.dismiss(animated: true)
    }

    func didDismissError() {
        errorMessage = nil
        didDismiss()
    }

    private func loadRawMessage() {
        loadingMessage = Text.loading.text
        Task {
            do {
                let rawString = try await bot.raw(of: keyValue)
                if let rawData = rawString.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: rawData)
                        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
                        rawMessage = String(data: data, encoding: .utf8)
                    } catch {
                        rawMessage = rawString
                    }
                } else {
                    rawMessage = rawString
                }
            } catch {
                Log.optional(error)
                errorMessage = error.localizedDescription
            }
            loadingMessage = nil
        }
    }
}
