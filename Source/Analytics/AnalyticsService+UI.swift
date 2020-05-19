//
//  AnalyticsService+UI.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {
    
    func trackDidTapTab(tabName: String) {
        self.track(event: .tap, element: .tab, name: tabName)
    }
    
    func trackDidTapButton(buttonName: String) {
        self.track(event: .tap, element: .button, name: buttonName)
    }
    
    func trackDidSelectAction(actionName: String) {
        self.track(event: .select, element: .action, name: actionName)
    }
    
    func trackDidTapSearchbar(searchBarName: String) {
        self.track(event: .tap, element: .searchBar, name: searchBarName)
    }
    
    func trackDidSelectItem(kindName: String) {
        self.track(event: .select, element: .item, name: kindName)
    }
    
    func trackDidSelectItem(kindName: String, param: String, value: String) {
        self.track(event: .select, element: .item, name: kindName, param: param, value: value)
    }
    
    func trackDidShowScreen(screenName: String) {
        self.track(event: .show, element: .screen, name: screenName)
    }
    
}
