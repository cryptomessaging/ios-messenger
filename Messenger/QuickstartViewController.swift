//
//  QuickstartViewController.swift
//  Messenger
//
//  Created by Mike Prince on 12/22/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import UIKit

class QuickstartViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var nicknameField: UITextField!
    
    @IBOutlet weak var morningButton: UIButton!
    @IBOutlet weak var shoppingButton: UIButton!

    fileprivate var doFilterPII = true  // pessimist, but check accessKey.acm
    fileprivate var hasAccessKey = false
    fileprivate var processingAction = false;   // TRUE when creating chat
    
    fileprivate var sunriseBot:Card?
    fileprivate var payBot:Card?
    fileprivate var shoppingBot:Card?
    
    class func presentQuickstart(_ parent:UIViewController) {
        let vc = QuickstartViewController(nibName: "QuickstartView", bundle: nil)
        let backButton = UIBarButtonItem(barButtonSystemItem:.cancel, target: vc, action: #selector(backAction) )
        vc.navigationItem.leftBarButtonItem = backButton
        
        let nav = UINavigationController(rootViewController: vc)
        parent.present(nav, animated: true, completion: nil)
    }
    
    func backAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true,completion:nil)
    }
    
    class func pushQuickstart(_ nav:UINavigationController) {
        let vc = QuickstartViewController(nibName: "QuickstartView", bundle: nil)
        nav.pushViewController(vc, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        edgesForExtendedLayout = UIRectEdge()
        
        hasAccessKey = MyUserDefaults.instance.getAccessKey() != nil
        if !hasAccessKey {
            // when there's no access key, its part of on-boarding, to give option to skip
            let nextButton = UIBarButtonItem(title:"Skip (Button)".localized, style: .plain, target: self, action: #selector(skipAction))
            navigationItem.rightBarButtonItem = nextButton
        }
        navigationItem.title = "Quickstart (Title)".localized
        
        morningButton.isEnabled = false
        shoppingButton.isEnabled = false
        
        nicknameField.delegate = self
        nicknameField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        hasAccessKey = MyUserDefaults.instance.getAccessKey() != nil
        if hasAccessKey {
            doFilterPII = AccessKeyHelper.checkPIIFilter()
        }
        
        loadBots()  // discover the bots we need
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .quickstart, vc:self )
    }
    
    func skipAction(_ sender: UIBarButtonItem) {
        //AskBirthdayViewController.showAskBirthday(self.navigationController!)
        SignupViewController.showSignup(self)
    }
    
    @IBAction func otherAction(_ sender: UIButton) {
        _ = navigationController?.popViewController(animated: false)
        
        let url = URL(string: "mailto:feedback@mobido.com?subject=My%20Family%20Needs%20Help%20With&body=(Tell%20us%20what%20you%20want%20to%20improve%20in%20your%20family)")
        UIApplication.shared.openURL(url!)
    }
    
    @IBAction func morningHelpAction(_ sender: UIButton) {
        if processingAction {
            return
        }
        
        lockControls()
        
        let botCids = [ self.sunriseBot!.cid!, self.payBot!.cid! ]
        if !hasAccessKey {
            QuickstartHelper.createAccessKey(self) {
                progress in
                
                if let progress = progress {
                    self.createCardAndChat( "Morning Chores".localized, botCids:botCids, progress:progress )
                } else {
                    self.unlockControls()
                }
            }
        } else {
            let progress = ProgressIndicator(parent: view, message: "Quickstarting (Progress)".localized )
            createCardAndChat( "Morning Chores".localized, botCids:botCids, progress:progress )
        }
    }
    
    @IBAction func shoppingHelpAction(_ sender: UIButton) {
        if processingAction {
            return
        }
        
        lockControls()
        
        let botCids = [ self.shoppingBot!.cid!, self.payBot!.cid! ]
        if !hasAccessKey {
            QuickstartHelper.createAccessKey(self) {
                progress in
                
                if let progress = progress {
                    self.createCardAndChat( "Grocery List".localized, botCids:botCids, progress:progress )
                } else {
                    self.unlockControls()
                }
            }
        } else {
            let progress = ProgressIndicator(parent: view, message: "Quickstarting (Progress)".localized )
            createCardAndChat( "Grocery List".localized, botCids:botCids, progress:progress )
        }
    }
    
    func createCardAndChat(_ subject:String,botCids:[String],progress:ProgressIndicator) {
        
        // create card
        let newCard = NewCard()
        newCard.nickname = StringHelper.clean(nicknameField.text)
        newCard.media = ImageHelper.toDataUri( ImageHelper.ZERO_LENGTH_BASE64 )
        
        MobidoRestClient.instance.createCard(newCard, progressHandler: nil ) {
            result in
            
            if ProblemHelper.showProblem(self, title: "Problem creating quickstart card (Alert Title)".localized, failure: result.failure ) {
                progress.stop()
                self.unlockControls()
                return
            }
            
            // update card in local cache
            let card = Card()
            card.cid = result.cid
            card.nickname = newCard.nickname
            MyCardsModel.instance.updateMyCardInCache(card, flushMedia: false)

            // create chat with bot already in it
            let newChat = NewPublicChat()
            newChat.subject = subject // "Morning Chores".localized
            newChat.cid = result.cid    // my cid
            newChat.allcids = [String]( arrayLiteral: result.cid! )
            newChat.allcids?.append( contentsOf: botCids )
            
            MobidoRestClient.instance.createPublicChat(newChat) {
                result in
                
                progress.stop()
                self.unlockControls()
                if ProblemHelper.showProblem(self, title: "Problem creating quickstart chat (Alert Title)".localized, failure: result.failure ) {
                    return
                }
                
                UIHelper.onMainThread {
                    // hint to open first bot when showing chat
                    let tid = result.thread!.tid!
                    MyUserDefaults.instance.setDefaultWidget(botCids.first, forThread:tid)
                    
                    // done with this screen
                    if self.hasAccessKey {
                        _ = self.navigationController?.popViewController(animated: true)
                    } else {
                        // move to main view
                        MainViewController.showMain()
                    }
                    
                    // delay a bit, then show new chat!
                    UIHelper.delay(0.5) {
                        NotificationHelper.signalShowChat( tid )
                    }
                }
            }
        }
    }
    
    func textFieldDidEndEditing( _ textField: UITextField) {
        NicknameHelper.alertIfNicknameInvalid(self,nickname: nicknameField.text, doFilterPII: doFilterPII )
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        enableButtons( NicknameHelper.isNicknameValid(nicknameField.text, doFilterPII: doFilterPII ) )
    }
    
    func enableButtons(_ enabled:Bool) {
        morningButton.isEnabled = enabled
        shoppingButton.isEnabled = enabled
    }
    
    func lockControls() {
        processingAction = true
        enableButtons( false )
        if nicknameField.isFirstResponder {
            nicknameField.resignFirstResponder()
        }
        nicknameField.isUserInteractionEnabled = false
    }
    
    func unlockControls() {
        processingAction = false
        enableButtons( NicknameHelper.isNicknameValid(nicknameField.text, doFilterPII: doFilterPII ) )
        nicknameField.isUserInteractionEnabled = true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()        
        return true
    }
    
    // we just want to find the sunrise, checklist, welcome, and grocery bot ids
    func loadBots() {
        PopularBotCardsModel.instance.fetchCards {
            failure, cards in
            
            // ignore failures
            guard let cards = cards else {
                return
            }
            
            DispatchQueue.main.async {
                for c in cards {
                    if c.nickname == "SunriseBot" {
                        self.sunriseBot = c
                    } else if c.nickname == "PayBot" {
                        self.payBot = c
                    } else if c.nickname == "ShoppingBot" {
                        self.shoppingBot = c
                    }
                }
                
                if self.sunriseBot == nil || self.payBot == nil || self.shoppingBot == nil {
                    let failure = Failure( message: "Failed to find SunriseBot, ShoppingBot, or PayBot".localized )
                    ProblemHelper.showProblem(self,title:"Problem finding bots".localized, failure:failure ) {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
            
        }
    }
}
