//
//  DebugUIViewController.swift
//  FBTT
//
//  Created by Christoph on 4/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class DebugUIViewController: DebugTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "Layout"
        self.settings = [contentViewController(), frameworks()]
        self.tableView.reloadData()
    }

    private func contentViewController() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "Not scrollable, small content",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: false, title: nil)
                let label = self.label()
                label.text = self.text()
                Layout.fillTop(of: controller.contentView, with: label)
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Not scrollable, large content",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: false, title: nil)
                let label = self.label()
                label.text = "\(self.text())\n\(self.text())\n\(self.text())\n\(self.text())\n"
                Layout.fill(view: controller.contentView, with: label)
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        // TODO https://app.asana.com/0/914798787098068/1118519385941099/f
        // TODO not sure why this does not animate the label resize correctly
        settings += [DebugTableViewCellModel(title: "Not scrollable, keyboard, large content",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: false, title: nil)
                controller.isKeyboardHandlingEnabled = true
                let field = self.textField()
                let label = self.label()
                label.text = "\(self.text())\n\(self.text())\n\(self.text())\n\(self.text())\n"
                Layout.fillTop(of: controller.contentView, with: field)
                Layout.fillSouth(of: field, with: label)
                label.pinBottomToSuperviewBottom()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Not scrollable, keyboard, top + bottom",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: false, title: nil)
                controller.isKeyboardHandlingEnabled = true
                Layout.fillTop(of: controller.contentView, with: self.textField())
                Layout.fillBottom(of: controller.contentView, with: self.textField())
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Scrollable, small content (no scrolling)",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: true, title: nil)
                let label = self.label()
                label.text = self.text()
                Layout.fillTop(of: controller.contentView, with: label)
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Scrollable, keyboard, medium content",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: true, title: nil)
                controller.isKeyboardHandlingEnabled = true
                let field = self.textField()
                let label = self.label()
                label.text = "\(self.text())\n\(self.text())"
                Layout.fillTop(of: controller.contentView, with: field)
                Layout.fillSouth(of: field, with: label)
                label.pinBottomToSuperviewBottom()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Scrollable, large content",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: true, title: nil)
                let label = self.label()
                label.text = "\(self.text())\n\(self.text())\n\(self.text())\n\(self.text())\n"
                Layout.fill(view: controller.contentView, with: label)
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        settings += [DebugTableViewCellModel(title: "Scrollable, keyboard",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: true, title: nil)
                controller.isKeyboardHandlingEnabled = true
                let field = self.textField()
                let label = self.label()
                label.text = "\(self.text())\n\(self.text())\n\(self.text())\n\(self.text())\n"
                Layout.fillTop(of: controller.contentView, with: field)
                Layout.fillSouth(of: field, with: label)
                label.pinBottomToSuperviewBottom()
                self.navigationController?.pushViewController(controller, animated: true)
            })]

        return ("ContentViewController", settings, nil)
    }

    private func frameworks() -> DebugTableViewController.Settings {

        var settings: [DebugTableViewCellModel] = []

        settings += [DebugTableViewCellModel(title: "JSON crashes Markdown",
                                             cellReuseIdentifier: DebugValueTableViewCell.className,
                                             valueClosure: {
                cell in
                cell.accessoryType = .disclosureIndicator
            },
                                             actionClosure: {
                _ in
                let controller = ContentViewController(scrollable: false, title: nil)
                let label = self.label()
                let text = "[**\\!bang**](https://duckduckgo.com/bang)"
                let md = text.decodeMarkdown()
                label.attributedText = md
                Layout.fillTop(of: controller.contentView, with: label)
                self.navigationController?.pushViewController(controller, animated: true)
        })]

        return ("Framework Issues", settings, nil)
    }

    private func label() -> UILabel {
        let label = UILabel(frame: CGRect.zero)
        label.backgroundColor = .debug
        label.font = .boldSystemFont(ofSize: 24)
        label.numberOfLines = 0
        label.textColor = .lightGray
        return label
    }

    private func textField() -> UITextField {
        let view = UITextField(frame: CGRect.zero)
        view.backgroundColor = .debug
        view.borderStyle = .roundedRect
        view.placeholder = "Tap to show keyboard"
        return view
    }

    private func textView() -> UITextView {
        let view = UITextView(frame: CGRect.zero)
        view.backgroundColor = .debug
        view.font = .boldSystemFont(ofSize: 24)
        view.isEditable = true
        view.isScrollEnabled = false
        return view
    }

    private func text() -> String {
        "A bunch of text to fill the screen and hopefully demonstrate how the ContentViewController's internal scrollView and contentView correctly handle a variety of different sized content."
    }
}
