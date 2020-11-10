//
//  AboutsMenu.swift
//  FBTT
//
//  Created by Christoph on 6/24/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class AboutsMenu: UIView {

    private var abouts: [About] = [] {
        didSet {
            self.tableView.reloadData()
            self.isHidden = self.abouts.isEmpty
            self.tableView.heightConstraint?.constant = self.tableView.rowHeight * CGFloat(min(self.abouts.count, 3))
            
            if self.abouts.count > 3 {
                // this makes it clear to the user that the area is scrollable
                self.tableView.flashScrollIndicators()
                self.tableView.showsVerticalScrollIndicator = true
            } else {
                // this isn't strictly necessary, but the indicator takes too long to disappear otherwise
                // hiding it manually is less jarring 
                self.tableView.showsVerticalScrollIndicator = false
            }
        }
    }

    let topSeparator = Layout.separatorView()

    lazy var tableView: UITableView = {
        let view = UITableView.forAutoLayout()
        view.dataSource = self
        view.delegate = self
        view.rowHeight = MiniAboutCellView.height
        view.constrainHeight(to: view.rowHeight * 3)
        view.allowsMultipleSelection = false
        view.allowsSelection = true
        view.backgroundColor = .appBackground
        view.register(MiniAboutTableViewCell.self, forCellReuseIdentifier: MiniAboutTableViewCell.className)
        view.separatorColor = UIColor.separator.middle
        view.separatorInset = UIEdgeInsets.zero
        view.tableFooterView = UIView()
        view.addSeparatorAsHeaderView()
        return view
    }()

    let bottomSeparator = Layout.separatorView()

    // MARK: Lifecycle

    init(isHidden: Bool = true) {
        super.init(frame: .zero)
        self.useAutoLayout()
        self.backgroundColor = .appBackground
        self.isHidden = isHidden
        Layout.fill(view: self, with: self.tableView)
        Layout.fillTop(of: self, with: self.topSeparator, respectSafeArea: false)
        Layout.fillBottom(of: self, with: self.bottomSeparator, respectSafeArea: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Abouts

    var didSelectAbout: ((About) -> Void)?

    func filter(by string: String?) {
        guard let string = string, !string.isEmpty else { self.hide(); return }
        self.show()
        AboutService.matching(string.withoutAtPrefix) {
            [weak self] abouts, _ in
            self?.abouts = abouts
        }
    }

    // MARK: Animations

    private var isShown = false

    func show(animated: Bool = true) {
        guard self.isShown == false else { return }
        self.isShown = true
        self.tableView.contentOffset = .zero
        self.isHidden = false
    }

    func hide(animated: Bool = true) {
        guard self.isShown else { return }
        self.isShown = false
        self.isHidden = true
    }
}

extension AboutsMenu: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.abouts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MiniAboutTableViewCell.className, for: indexPath)
        (cell as? MiniAboutTableViewCell)?.aboutView.update(with: self.abouts[indexPath.row])
        return cell
    }
}

extension AboutsMenu: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let about = self.abouts[indexPath.row]
        self.didSelectAbout?(about)
        AboutService.didMention(about.identity)
    }
}

private class MiniAboutTableViewCell: UITableViewCell {

    let aboutView = MiniAboutCellView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        Layout.fill(view: self.contentView, with: self.aboutView)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        aboutView.reset()
    }
}
