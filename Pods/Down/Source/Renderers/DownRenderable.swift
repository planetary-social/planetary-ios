//
//  DownRenderable.swift
//  Down
//
//  Created by Rob Phillips on 5/28/16.
//  Copyright © 2016-2019 Down. All rights reserved.
//

import Foundation

public protocol DownRenderable {
    /// A string containing CommonMark Markdown
    var markdownString: String { get set }
}
