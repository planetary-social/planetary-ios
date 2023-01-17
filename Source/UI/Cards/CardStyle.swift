//
//  CardStyle.swift
//  Planetary
//
//  Created by Martin Dutra on 12/1/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Use this enum to change how a card (IdentityCard or MessageCard) is displayed
enum CardStyle {
    /// A compact card is meant to be displayed in a one column list layout
    case compact

    /// A golden card is meant to be displayed in multi column grid layout
    case golden
}
