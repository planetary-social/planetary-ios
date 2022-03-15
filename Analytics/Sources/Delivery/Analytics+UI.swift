//
//  Analytics+UI.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

    func trackDidTapTab(tabName: String) {
        service.track(event: .tap, element: .tab, name: tabName)
    }

    func trackDidTapButton(buttonName: String) {
        service.track(event: .tap, element: .button, name: buttonName)
    }

    func trackDidSelectAction(actionName: String) {
        service.track(event: .select, element: .action, name: actionName)
    }

    func trackDidTapSearchbar(searchBarName: String) {
        service.track(event: .tap, element: .searchBar, name: searchBarName)
    }

    func trackDidSelectItem(kindName: String) {
        service.track(event: .select, element: .item, name: kindName)
    }

    func trackDidSelectItem(kindName: String, param: String, value: String) {
        service.track(event: .select, element: .item, name: kindName, param: param, value: value)
    }

    func trackDidShowScreen(screenName: String) {
        service.track(event: .show, element: .screen, name: screenName)
    }

}
