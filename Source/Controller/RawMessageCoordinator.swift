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

    private var message: Message

    private var bot: Bot

    @Published var rawMessage: String?
    
    @Published var loadingMessage: String?

    @Published var errorMessage: String?

    init(message: Message, bot: Bot) {
        self.message = message
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

    private func updateRawMessage(_ rawMessage: String) {
        self.rawMessage = rawMessage
        self.loadingMessage = nil
    }

    private func updateErrorMessage(_ errorMessage: String) {
        self.errorMessage = errorMessage
        self.loadingMessage = nil
    }

    private func loadRawMessage() {
        loadingMessage = Localized.loading.text
        Task.detached { [bot, message, weak self] in
            do {
                var rawMessage: String
                let rawString = try await bot.raw(of: message)
                if let rawData = rawString.data(using: .utf8) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: rawData)
                        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
                        rawMessage = String(data: data, encoding: .utf8) ?? rawString
                    } catch {
                        rawMessage = rawString
                    }
                } else {
                    rawMessage = rawString
                }
                await self?.updateRawMessage(rawMessage)
            } catch {
                Log.optional(error)
                await self?.updateErrorMessage(error.localizedDescription)
            }
        }
    }
}
