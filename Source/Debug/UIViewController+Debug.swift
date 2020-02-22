import Foundation
import UIKit

extension UIViewController {

    // TODO https://app.asana.com/0/914798787098068/1115428070578317/f
    // ensure the menu cannot be opened for shipping apps
    override open var canBecomeFirstResponder : Bool {
        return true
    }

    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        self.presentDebugMenu()
    }

    func presentDebugMenu() {
        guard self.presentingViewController == nil else { return }
        let controller = DebugViewController()
        let navController = UINavigationController(rootViewController: controller)
        self.present(navController, animated: true, completion: nil)
    }
}

extension AppConfigurations {

    // Not used anymore, it can be used to filter Mixpanel users
    func hasCompanyIdentities() -> Bool {
        #if DEBUG
            return true
        #else
            for configuration in self {
                guard let identity = configuration.identity else { continue }
                if Identities.verse.people.contains(where: { $0.1 == identity }) { return true }
                if Identities.planetary.people.contains(where: { $0.1 == identity }) { return true }
            }
            return false
        #endif
    }
}
