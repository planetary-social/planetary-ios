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

    
    let connectionAnimation = PeerConnectionAnimation()

    convenience init() {
        self.init(frame: CGRect.zero)

        self.connectionAnimation.useAutoLayout()
        Layout.fillLeft(of: self, with: self.connectionAnimation)
        self.connectionAnimation.constrainSize(to: self.connectionAnimation.totalDiameter)
        
        
        
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
                    self.update(with: statistics.peer, lastSyncDate: statistics.lastSyncDate, animated: animated)
                }
            case .failure:
                break
            }
        }
        AppController.shared.operationQueue.addOperation(operation)
    }

    // MARK: Update

    private func update(with peers: PeerStatistics, lastSyncDate: Date? = nil, animated: Bool = true) {
        self.update(local: peers.localCount, online: peers.onlineCount, animated: animated)
        self.setSync(lastSyncDate: lastSyncDate)
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
    
    
    @objc func triggerSync(sender : UITapGestureRecognizer) {
        self.connectionAnimation.searchAnimation()
        AppController.shared.missionControlCenter.sendMission()
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



/*

 */
