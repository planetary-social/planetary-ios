//
//  Tappable.swift
//  FBTT
//
//  Created by Christoph on 4/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

protocol Tappable {
    var tap: (() -> Void)? { get set }
    var tapOnURL: ((URL) -> Void)? { get set }
    var recognizer: UITapGestureRecognizer { get set }
}
