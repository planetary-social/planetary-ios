//
//  PeersView.swift
//  Planetary
//
//  Created by Christoph on 10/29/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class PeersView: UIView {

    override var isHidden: Bool {
        didSet {
            self.isHidden ? self.stop() : self.start()
        }
    }

    let onlineLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        return label
    }()

    let localLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        return label
    }()
    
    let syncedLabel: UILabel = {
        let label = UILabel.forAutoLayout()
        return label
    }()

    private var peerListView: UIView = UIView()
    
    let connectionAnimation = PeerConnectionAnimation(color: .networkAnimation)

    convenience init() {
        self.init(frame: CGRect.zero)

        self.addSubview(connectionAnimation)

        self.connectionAnimation.useAutoLayout()
        self.connectionAnimation.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        self.connectionAnimation.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

//        Layout.fillLeft(of: self, with: self.connectionAnimation)
        self.connectionAnimation.constrainSize(to: self.connectionAnimation.totalDiameter)
        
        
        peerListView.backgroundColor = .purple
        self.addSubview(peerListView)
        peerListView.useAutoLayout()

        peerListView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        peerListView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        peerListView.bottomAnchor.constraint(equalTo: self.connectionAnimation.topAnchor).isActive = true
        self.connectionAnimation.topAnchor.constraint(equalTo: peerListView.bottomAnchor).isActive = true

        
        self.addSubview(self.onlineLabel)

        self.onlineLabel.constrainLeading(toTrailingOf: self.connectionAnimation, constant: Layout.horizontalSpacing)
        self.onlineLabel.bottomAnchor.constraint(equalTo: self.connectionAnimation.centerYAnchor, constant: -1).isActive = true

        //self.addSubview(self.localLabel)
        //self.localLabel.constrainLeading(toTrailingOf: self.connectionAnimation, constant: Layout.horizontalSpacing)
        //self.localLabel.topAnchor.constraint(equalTo: self.connectionAnimation.centerYAnchor, constant: -5).isActive = true
        
        self.addSubview(self.syncedLabel)
        self.syncedLabel.constrainLeading(toTrailingOf: self.connectionAnimation, constant: Layout.horizontalSpacing)
        self.syncedLabel.topAnchor.constraint(equalTo: self.connectionAnimation.centerYAnchor, constant: 1).isActive = true
        
        
        
        self.update(local: 0, online: 0, animated: false)
        self.setSync(lastSyncDate: nil)
        
        let gesture = UITapGestureRecognizer(target: self, action:  #selector(self.triggerSync))
        self.addGestureRecognizer(gesture)


//        self.runSimulation()
    }


    // Ensure the timer is stopped to allow this to be released correctly.
    // If this is not called, then the running timer will cause a retain
    // cycle and each time the view is used, a new timer will be running,
    // eventually causing a hand on the Bot stats call.
    override func removeFromSuperview() {
        self.stop()
        super.removeFromSuperview()
    }

    func runSimulation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.update(local: 0, online: 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.update(local: 2, online: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.update(local: 3, online: 7)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.update(local: 5, online: 10)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            self.update(local: 30, online: 80)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                self.update(local: 8, online: 12)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                    self.update(local: 2, online: 6)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Bot polling

    private var timer: Timer?

    private func start() {
        self.setStats(animated: false)
        self.timer = Timer.scheduledTimer(timeInterval: 5.0,
                                          target: self,
                                          selector: #selector(poll(timer:)),
                                          userInfo: nil,
                                          repeats: true)
    }

    @objc private func poll(timer: Timer) {
        self.setStats()
    }

    private func stop() {
        self.timer?.invalidate()
        self.timer = nil
    }

    private func setStats(animated: Bool = true) {
        let operation = StatisticsOperation()
        operation.completionBlock = {
            switch operation.result {
            case .success(let statistics):
                DispatchQueue.main.async {
                    self.update(with: statistics, lastSyncDate: statistics.lastSyncDate, animated: animated)
                }
            case .failure:
                break
            }
        }
        AppController.shared.operationQueue.addOperation(operation)
    }

    // MARK: Update

    private func update(with statistics: BotStatistics, lastSyncDate: Date? = nil, animated: Bool = true) {
        let peers = statistics.peer
        self.update(local: peers.localCount, online: peers.onlineCount, animated: animated)
        setNumberOfPostsDownloaded(for: statistics)
        self.updatePeerList(with: peers)
    }
    
    private func updatePeerList(with peers: PeerStatistics) {
        
        peerListView.subviews.forEach { $0.removeFromSuperview() }

        var previousCell: UIView?
        
        for (address, identity) in peers.identities {
            
            
            let model = DebugTableViewCellModel(title: address,
                                                cellReuseIdentifier: OnlinePeerCell.className,
                                                valueClosure:
               {
                   cell in
                   cell.detailTextLabel?.text = identity
               },
                                                actionClosure: nil)
            let cell = OnlinePeerCell(style: .value1, reuseIdentifier: nil)
            cell.accessoryType = .none
            cell.detailTextLabel?.text = nil
            cell.detailTextLabel?.textColor = UIColor.secondaryText
            cell.textLabel?.textColor = UIColor.mainText
            cell.textLabel?.text = model.title
            cell.backgroundColor = UIColor.cardBackground
            model.valueClosure?(cell)
            cell.useAutoLayout()
            cell.constrainHeight(to: 50)
            cell.peerIdentifier = identity
            
            let gesture = UITapGestureRecognizer(target: self, action: #selector(peerCellTapped))
            cell.addGestureRecognizer(gesture)
            
            peerListView.addSubview(cell)
            
            if let previousCell = previousCell {
                cell.topAnchor.constraint(equalTo: previousCell.bottomAnchor).isActive = true
            } else {
                // If this is the first cell, constrain it to the peerListView
                cell.topAnchor.constraint(equalTo: peerListView.topAnchor).isActive = true
            }
            cell.widthAnchor.constraint(equalTo: peerListView.widthAnchor).isActive = true
            previousCell = cell
        }
        
        if previousCell != nil {
            previousCell!.bottomAnchor.constraint(equalTo: peerListView.bottomAnchor).isActive = true
        }
    }

    private func update(local: Int, online: Int, animated: Bool = true) {
 
        //self.setStatus(text: .countLocalPeers, label: self.localLabel, count: local)
        self.connectionAnimation.setDotCount(inside: true, count: local, animated: animated) {
            let delay = animated ? 1.2 : 0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.setStatus(text: .countOnlinePeers, label: self.onlineLabel, count: online)
                self.connectionAnimation.setDotCount(inside: false, count: online, animated: animated)
            }
        }
    }
    

    private func setStatus(text: Text, label: UILabel, count: Int) {
        let count = String(count)
        let string = text.text(["count": count])
        let attributed = NSMutableAttributedString(string: string)
        attributed.addFontAttribute(UIFont.verse.peerCount)
        let range = (string as NSString).range(of: count)
        attributed.addAttribute(.font, value: UIFont.verse.peerCountBold, range: range)
        attributed.addColorAttribute(UIColor.text.detail)
        label.attributedText = attributed
    }
    
    @objc private func peerCellTapped(sender: Any?) {
        let peerIdentifier = "@\((((sender as! UITapGestureRecognizer).view as! OnlinePeerCell).peerIdentifier)!).ed25519"
        AppController.shared.pushViewController(for: .about, with: peerIdentifier)
    }
    
    @objc func triggerSync(sender : UITapGestureRecognizer) {
        self.connectionAnimation.searchAnimation()
        AppController.shared.missionControlCenter.sendMission()
    }
    
    private func setNumberOfPostsDownloaded(for statistics: BotStatistics) {
        guard let launchStatistics = AppController.shared.statisticsAtLaunch else {
            return
        }
        
        let label = self.syncedLabel
        let downloadedMessageCount = statistics.db.lastReceivedMessage - launchStatistics.db.lastReceivedMessage
        let string = "Downloaded \(downloadedMessageCount) posts this session"
        let attributed = NSMutableAttributedString(string: string)
        attributed.addFontAttribute(UIFont.verse.peerCount)
        //let range = (string as NSString).range(of: count)
        //attributed.addAttribute(.font, value: UIFont.verse.peerCountBold, range: range)
        attributed.addColorAttribute(UIColor.text.detail)
        label.attributedText = attributed
    }
    
    private func setSync(lastSyncDate: Date?) {
        let text = Text.lastSynced
        let label = self.syncedLabel
        let string = text.text(["when": lastSyncText(from: lastSyncDate)])
        let attributed = NSMutableAttributedString(string: string)
        attributed.addFontAttribute(UIFont.verse.peerCount)
        //let range = (string as NSString).range(of: count)
        //attributed.addAttribute(.font, value: UIFont.verse.peerCountBold, range: range)
        attributed.addColorAttribute(UIColor.text.detail)
        label.attributedText = attributed
    }
    
    private func lastSyncText(from date: Date?) -> String {
        if let lastSyncDate = date {
            return self.format(date: lastSyncDate)
        } else {
            do {
                let timestamp = try Bots.current.lastReceivedTimestam()
                let miliseconds = timestamp/1000
                return self.format(date: Date(timeIntervalSince1970: miliseconds))
            } catch {
                return ""
            }
        }
    }
    
    private func format(date: Date?) -> String {
        guard let date = date else { return "" }
        let dateString = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
        let timeString = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
        let string = "\(dateString) @ \(timeString)"
        return string
    }
}

extension PeerStatistics {

    var onlineCount: Int {
        return self.currentOpen.count
    }

    // TODO to calculate local we need our IP address
    // TODO and find others that are on the same subnet
    var localCount: Int {
        var online = Set(self.currentOpen.compactMap { $0.1 })
        let pubs = Set(Environment.Constellation.stars.map { $0.feed })
        online.subtract(pubs)
        return online.count
    }
}

class OnlinePeerCell: UITableViewCell {
    
    var peerIdentifier: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
        self.accessoryType = .none
        self.accessoryView = nil
        self.removeSubviewsFromContentView()
    }

    private func removeSubviewsFromContentView() {
        for (_, subview) in self.contentView.subviews.enumerated() {
            subview.removeFromSuperview()
        }
    }
}


/*

 */
