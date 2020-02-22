//
//  OnboardingViewController.swift
//  FBTT
//
//  Created by Christoph on 5/10/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class EarlyAccessOnboardingViewController: UINavigationController {

    typealias Content = (title: String, body: String, button: String)
    private let content: [Content] = [("Hey there...",
                                       "You’re holding the first ever tech demo of (Codename) Verse.\n\nVerse aims to be the first mainsteam commercial client for a distributed social network. It’s built upon Scuttlebutt - a completely open source protocol.",
                                       "Okay..."),
                                      ("It's early days...",
                                       "This version is incredibly rough and there is a hell of a lot missing. And it’s running on a test network so you can’t use it to talk to non-Verse users right now.\n\nBut we thought you’d like to see it working and have a bit of a play.",
                                       "Right"),
                                      ("What can I do?",
                                       "Once you’ve set up your account, you will automatically be following members of the Verse team. To find other people to follow, go and look at our profiles and see our connections.\n\nYou can follow and unfollow people, read people’s posts and write your own for them.\n\nThere are no notifications yet, so check in every so often to see if there’s anything new.",
                                       "Got it"),
                                      ("Are you ready?",
                                       "If so, let’s start the process of making you a little profile. It should only take a second.\n\nWe won’t need your e-mail address or password or anything, because your identity is stored as a secret on the phone.\n\nJust don’t get too attached because this network may go away at any time!",
                                       "Let's do it")]

    init() {
        super.init(nibName: nil, bundle: nil)
        self.isNavigationBarHidden = true
        guard let controller = self.viewControllerForContent(at: 0) else { return }
        self.setViewControllers([controller], animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Content presentation

    private func viewControllerForContent(at index: Int) -> UIViewController? {
        guard let view = self.viewForContent(at: index) else { return nil }
        let controller = ContentViewController(scrollable: false, title: nil)
        Layout.center(view, in: controller.contentView, size: CGSize(width: 255, height: 500))
        return controller
    }

    private func viewForContent(at index: Int) -> UIView? {

        guard index >= 0 && index < self.content.count else { return nil }
        let content = self.content[index]

        let view = UIView.forAutoLayout()

        let titleLabel = UILabel.forAutoLayout()
        titleLabel.font = UIFont.systemFont(ofSize: 35, weight: .regular)
        titleLabel.text = content.title
        titleLabel.textColor = UIColor.verse.default
        Layout.fillTop(of: view, with: titleLabel, insets: nil, respectSafeArea: false)

        let bodyLabel = UILabel.forAutoLayout()
        bodyLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        bodyLabel.numberOfLines = 0
        bodyLabel.text = content.body
        bodyLabel.textColor = UIColor(rgb: 0x656565)
        Layout.add(subview: bodyLabel, toBottomOf: titleLabel, insets: UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0))

        let button = UIButton(type: .custom).useAutoLayout()
        button.addTarget(self, action: #selector(nextButtonTouchUpInside(button:)), for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        button.setBackgroundImage(UIImage.verse.onboardingButton, for: .normal)
        button.setTitle(content.button, for: .normal)
        button.tag = index
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.titleLabel?.textColor = .white
        view.addSubview(button)
        button.constrainLeadingToSuperview()
        button.pinTop(toBottomOf: bodyLabel, constant: 18)

        Layout.addSpacerViewFromBottomOfSuperview(toBottomOf: button)

        return view
    }

    private let createProfileViewController: EditAboutViewController = {
        let controller = EditAboutViewController()
        return controller
    }()

    private func presentCreateProfileViewController() {
        self.createProfileViewController.saveCompletion = {
            [weak self] _ in
            guard let me = self else { return }
            if AppConfiguration.hasCurrent { me.skipOnboarding() }
            else { me.startOnboarding() }
        }
        let navigationController = UINavigationController(rootViewController: self.createProfileViewController)
        self.present(navigationController, animated: true, completion: nil)
    }

    private func skipOnboarding() {

        // put calls into various parts of onboarding to test here
        if let configuration = AppConfiguration.current {
            AppController.shared.showProgress()
//            self.followVerseIdentities(using: configuration.bot!, with: configuration.identity!)
            self.letPubsFollow(using: configuration.bot!, with: configuration.identity!)
//            self.syncAndRefresh(using: configuration.bot!)
        }

        // otherwise this is the default action
        self.endOnboarding()
    }

    private func endOnboarding() {
        AppController.shared.hideProgress()
        AppController.shared.showMainViewController(animated: false)
        self.createProfileViewController.dismiss(animated: true, completion: nil)
    }

    // MARK: All the onboarding junk

    private var about: About?

    // TODO seems like this whole block of work could be
    // moved to a API.onboard(about) composite
    private func startOnboarding() {
        AppController.shared.showProgress()
        GoBot.shared.createSecret() {
            [weak self] secret, error in
            guard let me = self else { return }
            if me.alert(optional: error) { return }
            guard let secret = secret else { return }
            let configuration = AppConfiguration(with: secret)
            configuration.setDefaultName(me.createProfileViewController.about.name)
            configuration.network = NetworkKey.verse
            // TODO should this be done here or when everything succeeds?
            configuration.apply()
            me.login(with: configuration)
        }
    }

    private func login(with configuration: AppConfiguration) {
        guard let network = configuration.network else { return }
        guard let secret = configuration.secret else { return }
        guard let bot = configuration.bot else { return }
        bot.login(network: network, hmacKey: configuration.hmacKey, secret: secret) {
            [weak self] error in
            guard let me = self else { return }
            if me.alert(optional: error) { return }
            me.publishAbout(using: bot)
        }
    }

    private func publishAbout(using bot: Bot) {
        guard let identity = AppConfiguration.current?.identity else { return }
        let about = self.createProfileViewController.about.mutatedCopy(identity: identity)
        bot.publish(content: about) {
            [weak self] _, error in
            guard let me = self else { return }
            if me.alert(optional: error) { return }
            me.followVerseIdentities(using: bot, with: identity)
        }
    }

    private func followVerseIdentities(using bot: Bot, with identity: Identity) {

        for identity in Identities.verse.all {
            bot.follow(identity.value) {
                _, error in
                Log.optional(error)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.letPubsFollow(using: bot, with: identity)
        }
    }

    private func letPubsFollow(using bot: Bot, with identity: Identity) {
        self.letPubFollow(identity) {
            [weak self] error in
            Log.optional(error)
            self?.syncAndRefresh(using: bot)
        }
    }

    // copied from henry's PR
    private func letPubFollow(_ identity: Identity, completion: @escaping ((Error?)->Void)) {
        var pubFollowURL = URLComponents()
        pubFollowURL.scheme = "https"
        pubFollowURL.host = "pub.verse.app"
        pubFollowURL.port = 443
        pubFollowURL.path = "/v1/invite"

        var listingReq = URLRequest(url:  pubFollowURL.url!)
        listingReq.addValue("orE5OWByYfaE7S0LziQGqA0Sb39+uYzSqRZ5sO9rPaI=", forHTTPHeaderField: "Verse-Authorize-Pub")
        listingReq.addValue(identity, forHTTPHeaderField: "Verse-New-Key")

        let task = URLSession.shared.dataTask(with: listingReq, completionHandler: { (pubFollowData, response, error) in
            var err: Error? = nil

            defer {
                DispatchQueue.main.async { completion(err) }
            }

            if let httpErr = error {
                err = GoBotError.duringProcessing("pubFollow http error:", httpErr)
                return
            }

            guard let urlResp = response as? HTTPURLResponse else {
                err = GoBotError.unexpectedFault("pubFollow: not a HTTPURLResponse")
                return
            }

            if urlResp.statusCode != 201 {
                err = GoBotError.unexpectedFault("pubFollow resp code: \(urlResp.statusCode)")
            }
        })
        task.resume()
    }

    private func syncAndRefresh(using bot: Bot) {
        bot.sync() {
            error, _ in
            Log.optional(error)
            bot.refresh() {
                [weak self] error, _ in
                Log.optional(error)
                self?.endOnboarding()
            }
        }
    }

    // TODO this needs to clean up everything if there were errors
    private func alert(optional error: Error?) -> Bool {
        guard Log.optional(error) else { return false }
        AppController.shared.hideProgress() {
            let controller = self.presentedViewController ?? self
            controller.alert(message: "Apologies, some thing went wrong.  We've logged the error for investigation, but please try again.",
                             cancelTitle: "OK")
        }
        // TODO logout needs optional completion
        AppConfiguration.current?.bot?.logout() { _ in }
        AppConfiguration.current?.unapply()
        return true
    }

    // MARK: Actions

    @objc func nextButtonTouchUpInside(button: UIButton) {

        let index = button.tag + 1
        if index == 4 {
            self.presentCreateProfileViewController()
        }

        else if let controller = self.viewControllerForContent(at: index) {
            self.pushViewController(controller, animated: true)
        }

        // TODO if hosted from the Debug menu how to dismiss?
        else {
            self.dismiss(animated: true, completion: nil)
        }
    }
}
