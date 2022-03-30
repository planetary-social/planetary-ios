import Foundation
import UIKit

extension UIViewController {

    // TODO https://app.asana.com/0/914798787098068/1115428070578317/f
    // ensure the menu cannot be opened for shipping apps
    override open var canBecomeFirstResponder: Bool {
        true
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
