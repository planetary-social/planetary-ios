//
//  Created by Christoph on 2/26/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class Bots {

    static var all: [Bot] {
        [FakeBot.shared, GoBot.shared]
    }

    static func bot(named name: String) -> Bot? {
        let bots = Bots.all.filter { $0.name == name }
        return bots.first
    }

    static var current: Bot {
        self._bot
    }

    static func select(_ bot: Bot) {
        self._bot = bot
    }

    static func isSelected(_ bot: Bot) -> Bool {
        self._bot.name == bot.name
    }

    // TODO might need NullBot?
    // default is FakeBot to ensure Bots.current is not optional
    private static var _bot: Bot = GoBot.shared
}
