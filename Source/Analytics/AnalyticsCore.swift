//
//  Analytics.swift
//  FBTT
//
//  Created by Christoph on 3/2/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

protocol AnalyticsCore {

    var isEnabled: Bool { get }

    func configure()
    func identify(about: About?, network: NetworkKey)
    func optIn()
    func optOut()
    func forget()

    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               params:  AnalyticsEnums.Params?)
}

extension AnalyticsCore {

    // MARK: Track single param

    func track(event: AnalyticsEnums.Event,
               element: AnalyticsEnums.Element,
               name: AnalyticsEnums.Name.RawValue,
               param: String? = nil,
               value: String? = nil)
    {
        var params: AnalyticsEnums.Params = [:]
        if let param = param, let value = value { params[param] = value }
        self.track(event: event,
                   element: element,
                   name: name,
                   params: params)
    }

    // MARK: Log
    // Use Lumberjack instead
    @available(*, deprecated)
    func log(_ name: AnalyticsEnums.Name.Log, _ message: String) {
        let params: AnalyticsEnums.Params = ["message": message]
        self.track(event: .log,
                   element: .app,
                   name: name.rawValue,
                   params: params)
    }
}
