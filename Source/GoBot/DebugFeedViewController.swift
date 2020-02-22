//
//  DebugFeedViewController.swift
//  FBTT
//
//  Could also work with the JS Sbot but right now it's sepcific to the Go bot
//
//  Created by Henry Bubert on 23.01.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

func DebugMessageToString(msg: KeyValue) -> String {
    var title = msg.key
    switch msg.value.content.type {
    case .about:
        guard let a = msg.value.content.about else {
            print("weird about message: \(msg.key): \(msg.value.content.contentException ?? "")")
            return title
        }
        
        let aboutSelf = msg.value.author == a.about
        let who: String
        if aboutSelf {
            who = "self"
        } else {
            who = a.about
        }
        
        if let name = a.name {
            title += " named \(name)"
        }
        if let img = a.image {
            title += " changed avatar to \(img)"
        }
        if let descr = a.description {
            title += descr
        }
        title += who
        
        
    case .contact:
        guard let c = msg.value.content.contact else {
            print("weird contact message: \(msg.key): \(msg.value.content.contentException ?? "")")
            return title
        }
        let following = c.following
        let blocking = c.blocking
        
        if following ?? false {
            title = "followed \(c.contact)"
        } else if blocking ?? false {
            title = "blocked \(c.contact)"
        } else {
            title = "unfollow/block of \(c.contact)"
        }
        
    case .post:
        title = msg.value.content.post!.text
    case .vote:
        guard let v = msg.value.content.vote else {
            print("weird vote message: \(msg.key)")
            return title
        }
        //                    if let lnk =  {
        title = "voted \(v.vote.link)"
        //                    }
        
        //                case .gitUpdate:
        //                    title = "git push"
        //                case .gitRepo:
        //                    title = "created a git repo"
        //                case .pub:
        //                    title = "advertised a pub"
        
    case .unsupported:
        title = "unsupported \(msg.value.content.typeString)"
    default:
        title = "TODO:default \(msg.value.content.typeString)"
    }
    return title
}

class DebugFeedOverviewViewController: DebugTableViewController {

    convenience init() {
        self.init(nibName: nil, bundle: nil)
        self.navigationItem.title = "Feed list"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        GoBot.shared.bot.getFeedList() {
            feeds, err in
            if let e = err {
                Log.optional(e)
                return
            }
            self.fillFeeds(feedDict: feeds)
        }
        self.settings = [("Feeds", [], nil)]
    }

    func fillFeeds(feedDict: [Identity: Int]) {
        var feeds: [DebugTableViewCellModel] = []
        for (feed, currSeq) in feedDict {

            let index = feed.index(feed.startIndex, offsetBy: 7)
            var name = String(feed[..<index])
            do {
                if let n = try GoBot.shared.database.getName(feed: feed) {
                    name = n
                }
            } catch {
                // print("no name for \(feed)")
            }
            feeds += [DebugTableViewCellModel(title: name,
                                              cellReuseIdentifier: DebugValueTableViewCell.className,
                                              valueClosure:
                {
                    cell in
                    cell.detailTextLabel?.text = String(currSeq)
                },
                                              actionClosure:
                {
                    cell in
                    let feedView = DebugFeedLogViewController(feed: feed)
                    self.navigationController?.pushViewController(feedView, animated: true)
                }
            )]
        }

        self.settings = [("Feeds", feeds, nil)]
        self.tableView.reloadData()
    }
}


class DebugFeedLogViewController: DebugTableViewController {
    private var feed: Identity = ""

    convenience init(feed: Identity) {
        self.init(nibName: nil, bundle: nil)
        
        var name = "Feed \(feed)" // default fallback
        do {
            if let n = try GoBot.shared.database.getName(feed: feed) {
                name = "Feed @\(n)"
            }
        } catch {
            print("view db error:", error)
        }
        self.navigationItem.title = name
        
        GoBot.shared.feed(identity: feed) {
            msgs, err in
            DispatchQueue.main.async {
                self.fillMessages(msgs: msgs, err: err)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func fillMessages(msgs: [KeyValue], err: Error?) {
        if let e = err {
            print("failed to fill messages:", e)
            return
        }
        
        var uiElems: [DebugTableViewCellModel] = []
        for msg in msgs {
            
            if !msg.value.content.isValid {
                print("ignored invalid message: \(msg.key): \(msg.value.content.contentException ?? "<nil>")")
                continue
            }

            let title = DebugMessageToString(msg: msg)

            uiElems += [DebugTableViewCellModel(title: title,
                                              cellReuseIdentifier: DebugValueTableViewCell.className,
                                              valueClosure:
                {
                    cell in
                    cell.accessoryType = .detailButton
                },
                                              actionClosure:
                {
                    cell in
                    
                    if !msg.value.content.isValid {
                        return
                    }
                    
                    var wantedKey: MessageIdentifier = msg.key
                    
                    if msg.value.content.type == .vote {
                        if let voteRef = msg.value.content.vote?.vote.link {
                            wantedKey = voteRef
                        }
                    } else if msg.value.content.type == .post {
                        if let rootKey = msg.value.content.post?.root {
                            wantedKey = rootKey
                        }
                    }
                    let feedView = DebugMessageViewController(root: wantedKey)
                    self.navigationController?.pushViewController(feedView, animated: true)
                }
            )]
        }
        
        self.settings = [("Messages", uiElems, nil)]
        self.tableView.reloadData()
    }
}

class DebugMessageViewController: DebugTableViewController {
    private var root: MessageIdentifier = ""
    private var replies: [KeyValue] = []
    
    convenience init(root: MessageIdentifier) {
        self.init(nibName: nil, bundle: nil)
        self.root = root
        
        do {
            self.replies = try GoBot.shared.database.getRepliesTo(thread: self.root)
        } catch {
            print("query for replies failed:", error)
        }
        
        do {
            let rootMsg = try GoBot.shared.database.get(key: self.root)
            self.settings += [("Root", [DebugTableViewCellModel(title: DebugMessageToString(msg: rootMsg),
                                                                cellReuseIdentifier: DebugValueTableViewCell.className,
                                                                valueClosure:
                {
                    cell in
                    cell.accessoryType = .none
                },
                                                                actionClosure: nil
                )]
            , nil)]
        } catch {
            print("failed to get root message:", error)
        }
        
        var repliesUIelems: [DebugTableViewCellModel] = []
        for msg in self.replies {
            repliesUIelems += [DebugTableViewCellModel(title: DebugMessageToString(msg: msg),
                                     cellReuseIdentifier: DebugValueTableViewCell.className,
                                     valueClosure:
                {
                    cell in
                    cell.accessoryType = .none
                },
                                     actionClosure: nil
            )]
        }
        self.settings += [("Replies", repliesUIelems, nil)]
        self.tableView.reloadData()
    }
}

