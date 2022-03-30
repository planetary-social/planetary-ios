import Foundation
import UIKit

class DebugTableViewController: UITableViewController {

    typealias Settings = (header: String?, cellModels: [DebugTableViewCellModel], footer: String?)

    /// Set in subclass' viewDidLoad() to customize.
    var settings: [Settings] = []

    convenience init() {
        self.init(style: .grouped)
    }

    /// Subclasses are encouraged to register their own custom UITableViewCells.
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.backgroundColor = UIColor.appBackground
        self.tableView.register(DebugValueTableViewCell.self, forCellReuseIdentifier: DebugValueTableViewCell.className)
        self.tableView.register(DebugSubtitleTableViewCell.self, forCellReuseIdentifier: DebugSubtitleTableViewCell.className)
        self.tableView.register(DebugImageTableViewCell.self, forCellReuseIdentifier: DebugImageTableViewCell.className)
        self.removeBackItemText()
    }

    /// Calls updateSettings()
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateSettings()
    }

    /// Subclasses are encouraged to override to update their settings, and calling
    /// super is required to reload the table view.
    internal func updateSettings() {
        self.tableView.reloadData()
    }

    // MARK: - UITableViewDataSource

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.settings[section].header
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.settings[section].footer
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.settings.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.settings[section].cellModels.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = self.settings[indexPath.section].cellModels[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: model.cellReuseIdentifier, for: indexPath)
        cell.accessoryType = .none
        cell.detailTextLabel?.text = nil
        cell.detailTextLabel?.textColor = UIColor.secondaryText
        cell.textLabel?.textColor = UIColor.mainText
        cell.textLabel?.text = model.title
        cell.backgroundColor = UIColor.cardBackground
        model.valueClosure?(cell)
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let model = self.settings[indexPath.section].cellModels[indexPath.row]
        if let cell = tableView.cellForRow(at: indexPath) {
            model.actionClosure?(cell)
            model.valueClosure?(cell)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
