//
//  HomeBotViewController.swift
//  Messenger
//
//  Created by Mike Prince on 6/13/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import UIKit
import WebKit
import ObjectMapper

extension UIColor {
    convenience init(rgb:UInt, alpha:CGFloat = 1.0) {
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: CGFloat(alpha)
        )
    }
}

class HomeBotViewController : UIViewController, BotScriptDelegate {
    
    enum MyCardLoadingStatus: String {
        case loading
        case success
        case failure
    }
    var myCardsLoaded = MyCardLoadingStatus.loading
    
    var mytitle:String!
    var url:String!
    
    var userCard:Card?
    var botCard:Card?
    var metapage:MetapageResult?
    var abouturl:URL?
    fileprivate var isRestClientReady = false
    
    //fileprivate let scriptMessageHandler = ScriptMessageHandler()
    //fileprivate var botWidget:BotWidget?
    fileprivate let optionButton = BotOptionButton()
    fileprivate let botScriptBridge = BotScriptBridge()
    fileprivate var webview:WKWebView!
    
    class func createViewController() -> UIViewController {
        let botvc = HomeBotViewController()
        return UINavigationController( rootViewController: botvc )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //===== Wire in WKWebView =====

        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = BotHelper.createUserContentController()!
        webview = WKWebView(frame: view.frame, configuration: webViewConfig )
        webview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview( webview )
        
        botScriptBridge.delegate = self
        botScriptBridge.webview = webview
        
        //===== Add navigation =====
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        navigationItem.title = "Mobido Homepage (Title)".localized
        
        // make sure my cards are loaded
        let mycards = MyCardsModel.instance
        mycards.loadWithProblemReporting(.local, statusCallback:nil ) {
            success in
            
            self.myCardsLoaded = success ? MyCardLoadingStatus.success : MyCardLoadingStatus.failure
            if !success {
                return
            }
            
            // has the user already selected a card for this page?
            let prefs = MyUserDefaults.instance
            if let mycid = prefs.get(.HOMEPAGE_DEFAULT_USER_CID) {
                if let card = CardHelper.findCard(mycid, inCards: mycards.cards ) {
                    self.userCard = card
                    self.fixupRestClient()
                } else {
                    // no longer available, so forget it!
                    prefs.set(.HOMEPAGE_DEFAULT_USER_CID, withValue: nil)
                }
            }
        }
        
        // Page start-up
        // 1. Get bot id
        // 2. Get bot card (for metapage url)
        // 3. Get metapage (for homepage url and cryptos)
        // 4. Get homepage HTML
        
        beginSelectingHomebot(useCache:true)
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        //AnalyticsHelper.trackView(.HomeBotPage)
        
        let image = UIImage(named:"Switch")
        let changeBotButton = UIBarButtonItem(image:image, style:.plain, target: self, action: #selector(changeBotAction))
        if MyUserDefaults.instance.check(.IsWidgetDeveloper) {
            let refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshAction))
            navigationItem.rightBarButtonItems = [ changeBotButton, refreshButton ]
        } else {
            navigationItem.rightBarButtonItem = changeBotButton
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )
        AnalyticsHelper.trackScreen( .homeBot, vc:self )
    }
    
    fileprivate func setupAboutButton() {
        UIHelper.onMainThread {
            if self.abouturl != nil {
                let aboutIcon = UIImage(named:"About")?.withRenderingMode(.alwaysOriginal)
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(image:aboutIcon, style: .plain, target: self, action:#selector(self.aboutButtonAction) )
            } else {
                self.navigationItem.leftBarButtonItem = nil
            }
        }
    }
    
    func aboutButtonAction(_ sender: AnyObject) {
        if let url = abouturl, let nickname = botCard?.nickname {
            let title = String(format:"About %@ (Title)".localized, nickname )
            WebViewController.showWebView(self, url:url, title:title, screenName: .aboutHomepage )
        }
    }
    
    func backButtonAction(_ sender: AnyObject) {
        botScriptBridge.onBackButton()
    }
    
    func refreshAction(_ sender: AnyObject) {
        MyUserDefaults.instance.set(.HOMEPAGE_DEFAULT_USER_CID, withValue: nil)
        userCard = nil
        beginSelectingHomebot(useCache:true)
    }
    
    //===== Bot selection process =====
    
    // handler for "switch bot" navigation bar button
    func changeBotAction(_ sender: AnyObject) {
        let progress = SimpleProgressIndicator(parent: self.view, message: "Loading homepage (Progress)".localized )
        fetchHomebotCards(useCache:true,progress:progress, chooseFirstBot:false )
    }
    
    fileprivate func beginSelectingHomebot(useCache:Bool) {
        
        let progress = SimpleProgressIndicator(parent: self.view, message: "Loading homepage (Progress)".localized )
        
        // 1. Get bot id
        if let cid = MyUserDefaults.instance.get(.HOMEPAGE_MANAGER_CID) {
            fetchBot(cid:cid,useCache:useCache,progress:progress)
            return
        }
        
        fetchHomebotCards(useCache:useCache, progress:progress, chooseFirstBot:true)
    }
    
    fileprivate func fetchHomebotCards(useCache:Bool, progress:SimpleProgressIndicator, chooseFirstBot:Bool) {
        
        // get the list of all bots and ask user to choose
        let model = HomepageBotCardsModel.instance
        model.fetchCards {
            failure, cards in
            
            if let failure = failure {
                // uh oh... a problem
                ProblemHelper.showProblem(nil, title: "Failed To Fetch Homepage Bots (Title)".localized, failure: failure)
                
                // but maybe, we got a few cards...
                if model.cardsLoaded.count > 0 {
                    self.chooseHomebotFromList( useCache:useCache, cards: model.cardsLoaded, progress:progress )
                } else {
                    // no cards?  full stop
                    progress.stop()
                }
            } else if model.lastCardLoad > 0 {
                // good news: all done!
                if chooseFirstBot && model.cardsLoaded.count > 0 {
                    //let json = Mapper().toJSONString(model.cardsLoaded, prettyPrint:true)
                    //print( "All homepage bots loaded \(json)" )
                    self.useSelectedHomebot( card:model.cardsLoaded.first!, progress:progress )
                } else {
                    self.chooseHomebotFromList( useCache:useCache, cards: model.cardsLoaded, progress:progress )
                }
            } else {
                // still waiting for more cards...
            }
        }
    }
    
    fileprivate func chooseHomebotFromList(useCache:Bool, cards:[Card], progress:SimpleProgressIndicator) {
        if cards.count == 1 {
            useSelectedHomebot( card:cards.first!, progress:progress )
        } else {
            var items = [KeyedLabel]()
            for c in cards {
                if let cid = c.cid, let nickname = c.nickname {
                    items.append( KeyedLabel( key:cid, label:nickname ) )
                }
            }
            
            progress.stop()
            let title =  "Select a Homepage Bot (Title)".localized
            let options = ListPickerOptions()
            options.screenName = .homepageBotPicker
            options.result = .homepageBotPicked
            ListPickerViewController.showPicker( self.navigationController!,title:title,items:items, options:options) {
                selected in
                
                let progress = SimpleProgressIndicator(parent: self.view, message: "Loading homepage (Progress)".localized )
                var found:Card?
                for c in cards {
                    if selected.key == c.cid {
                        found = c
                    }
                }
                self.useSelectedHomebot( card:found!, progress:progress )
            }
        }
    }
    
    fileprivate func useSelectedHomebot( card:Card, progress:SimpleProgressIndicator ) {
        guard let cid = card.cid else {
            progress.stop()
            ProblemHelper.showProblem(self, title: "Problem With Homepage Bot Listing (Title)".localized, message: "Bot listing missing identifier (Error)".localized )
            return
        }
        
        MyUserDefaults.instance.set(.HOMEPAGE_MANAGER_CID, withValue: cid)
        self.navigationItem.title = card.nickname
        self.fetchMetapage(card:card, progress:progress)
    }
    
    fileprivate func fetchBot(cid:String,useCache:Bool,progress:SimpleProgressIndicator) {
        
        // 2. get bot card
        if useCache == false {
            LruCache.instance.removeCard(cid:cid)
        }

        CardHelper.fetchPublicCard(cid) {
            card, failure in
            
            if ProblemHelper.showProblem(self, title: "Problem Fetching Homepage Bot (Title)".localized, failure: failure ) {
                progress.stop()
                return
            }
            
            guard let card = card else {
                ProblemHelper.showProblem(self, title: "Problem Fetching Homepage Bot (Title)".localized, message: "No matching persona found (Error)".localized )
                progress.stop()
                return
            }
            
            // update title to botCard
            self.navigationItem.title = card.nickname
            
            self.fetchMetapage(card:card, progress:progress)
        }
    }
    
    fileprivate func fetchMetapage(card:Card, progress:SimpleProgressIndicator) {
        // get the bot metadata/manifest
        botCard = card
        BotHelper.loadMetapage( card ) {
            metapage, metaurl in
            
            if let failure = metapage.failure {
                ProblemHelper.showProblem( nil, title: "Problem Loading Bot (Title)".localized, failure: failure )
                progress.stop()
                return
            }
            
            self.metapage = metapage
            
            guard let homepage = metapage.homepage else {
                ProblemHelper.showProblem( nil, title: "Problem Loading Bot (Title)".localized, message: "No homepage provided (Error)".localized )
                progress.stop()
                return
            }
            
            if let pageurl = metapage.aboutpage?.url {
                self.abouturl = URL( string:pageurl, relativeTo:metaurl )
                self.setupAboutButton()
            }
            
            guard let url = homepage.url else {
                ProblemHelper.showProblem( nil, title: "Problem Loading Bot (Title)".localized, message: "Homepage URL missing (Error)".localized )
                progress.stop()
                return
            }
            
            // if homepage is relative, resolve
            if let fullurl = URL( string:url, relativeTo:metaurl ) {
                self.fetchHomepage(url:fullurl,progress:progress)
                self.fixupRestClient()
            } else {
                let message = String( format:"Failed to resolve homepage url from %@ and %@ (Error)".localized, url, metaurl! as CVarArg )
                ProblemHelper.showProblem( nil, title: "Problem with Bot".localized, message:message )
                progress.stop()
            }
        }
    }
    
    fileprivate func fixupRestClient() {
        // race condition to get here... both the bot info is loading AND my cards might be loading
        // SOOO don't proceed until we have both :)
        guard let botCard = self.botCard, let metapage = self.metapage else {
            // not enough to even start, so delay
            return
        }
        
        if userCard != nil {
            prepareRestClient( tid:nil ) {
                failure, card in
            }
            return
        }
        
        /* fall through to crafting an anonymous rest client
        self.botWidget = BotWidget( tid:nil, mycid:nil, botCard:self.botCard!, scriptMessageHandler:self.scriptMessageHandler )
        self.botWidget?.restClient = BotRestClient( mycid:nil, privateKey:nil, tid:nil, botCard:botCard, metapage:metapage )
        self.scriptMessageHandler.botWidget = self.botWidget
        self.scriptMessageHandler.secureRequests = false    // disable security for now...
         */
        
        botScriptBridge.reset( mycid:nil, privateKey:nil, tid:nil, botCard:botCard, metapage:metapage )
        
        botScriptBridge.secureRequests = false
    }
    
    fileprivate func fetchHomepage(url:URL, progress:SimpleProgressIndicator) {
        
        let restClient = BotRestClient()
        restClient.fetchHTML( url.absoluteString, secure:false ) {
            failure, html in
            
            progress.stop()
            
            if let failure = failure {
                ProblemHelper.showProblem( nil, title: "Failed To Get Widget HTML (Title)".localized, failure: failure )
            } else {
                // make sure this happens on UI thread
                DispatchQueue.main.async {
                    _ = self.webview?.loadHTMLString( html!, baseURL: url )
                }
            }
        }
    }
    
    //===== Bot Script Delegate =====
    
    func doSetupScreen( _ options:ScreenOptions ) {
        // make nav bar transparent
        guard let nav = self.navigationController else {
            DebugLogger.instance.append(function: "doSetupScreen()", message: "Failed to find navigation controller" )
            return
        }

        let bar = nav.navigationBar
            //bar.setBackgroundImage(UIImage(), for: .default)
            //bar.shadowImage = UIImage()
            //bar.isTranslucent = true
        
        if let header_background = options.header_background {
            bar.barTintColor = UIColor(rgb: header_background )
        }
        
        if let header_tint = options.header_tint {
            bar.tintColor = UIColor(rgb: header_tint )
        }
    }
    
    func doCloseBotWidget() {
        UIHelper.unwind( vc:self )
    }
    
    func doBotWidgetHeightChange(_ height:CGFloat) {
        // ignored
    }
    
    func fetchThreadCards() -> [Card]? {
        // this isn't a chat, so no thread cards!
        return nil
    }
    
    // TODO - race condition here, might be requested before my cards have been loaded... TBD how to handle?
    func fetchUserCard() -> Card? {
        return userCard
    }
    
    func doSelectUserCard( options:SelectUserCardOptions?, completion:@escaping ( Failure?, Card?) -> Void ) -> Void {
        if myCardsLoaded != .success {
            let failure = Failure( message:"Failed to load your personas (Error)".localized )
            completion( failure, nil )   // signal back error status
            return
        }
        
        AnalyticsHelper.trackActivity(.selectUserCard)
        
        let cards = MyCardsModel.instance.cards
        if cards.isEmpty {
            EditCardViewController.showCreateCard(self.navigationController!) {
                card in
                
                if let card = card {
                    self.rememberCard( card )
                    self.prepareRestClient( tid:nil, completion:completion )
                } else {
                    AnalyticsHelper.trackResult(.selectUserCardCancelled)
                    completion(nil,nil)     // implies "cancelled"
                }
            }
            return
        }
        
        let title = options?.title != nil ? options!.title! : "Who Do You Want To Post As? (Title)".localized
        WhichMeViewController.showWhichMePopover(self.navigationController!, cards:cards, title:title, offerCreate: true ) {
            card in
            
            if let card = card {
                // has the card changed?
                if card.cid != self.userCard?.cid {
                    self.isRestClientReady = false
                }
                
                self.rememberCard( card )
                self.prepareRestClient( tid:nil, completion:completion )
            } else {
                AnalyticsHelper.trackResult(.selectUserCardCancelled)
                completion(nil,nil)     // implies "cancelled"
            }
        }
    }
    
    fileprivate func rememberCard( _ card:Card ) {
        self.userCard = card
        MyUserDefaults.instance.set( .HOMEPAGE_DEFAULT_USER_CID, withValue:card.cid )
    }
    
    func doEnsureExclusiveChat( subject:String?, updateRestClient:Bool, _ completion:@escaping( _ failure:Failure?, _ thread:ChatThread?) -> Void ) -> Void {
        guard let userCard = self.userCard, let botCard = self.botCard else {
            completion( Failure( message: "Your persona must be selected first (Error)".localized ), nil )
            return
        }
        
        ExclusiveChatHelper.ensureExclusiveChat( parent: self.view, mycard:userCard, peer:botCard, subject:subject ) {
            failure, thread in
            
            if let failure = failure {
                completion(failure,nil)
                return
            }
            
            if updateRestClient == false {
                completion(nil,thread)
                return
            }
            
            self.prepareRestClient( tid:thread!.tid ) {
                failure, card in
                completion(failure,thread)
            }
        }
    }
    
    func doShowChat( _ options:ShowChatOptions ) {
        if let tid = options.tid {
            NotificationHelper.signalShowChat( tid );
        }
    }
    
    func fetchBotCard() -> Card? {
        return botCard // botScriptDelegate?.onBotCardRequest()
    }
    
    func fetchThreadList( _ tids:[String] ) -> ThreadListResult {
        return ThreadListResult() // botScriptDelegate!.onThreadListRequest(tids)
    }
    
    func fetchThread() -> ChatThread? {
        return nil //botScriptDelegate?.onThreadRequest()
    }
    
    func fetchMessageHistory() -> [ChatMessage]? {
        return nil //botScriptDelegate?.onMessageHistoryRequest()
    }
    
    func doSetOptionButtonItems( _ items:[OptionItem] ) {
        optionButton.items = items
    }
    
    func doEnvironmentFixup( _ env:inout WidgetEnvironment ) {
        env.fullscreen = true
    }
    
    func doSetBackButton( _ options:BackButtonOptions? ) {
        if let options = options {
            if let title = options.title {
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: title, style: .plain, target: self, action: #selector(backButtonAction) )
            } else {
                navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action:#selector(backButtonAction) )
            }
        } else {
            setupAboutButton()
        }
    }
    
    //===== When a user card is selected, refresh the REST client =====
    
    // expects userCard and metapage are already loaded
    fileprivate var latestRacer:NSObject?
    fileprivate func prepareRestClient( tid:String?, completion:@escaping ( Failure?, Card?) -> Void ) {
        guard let card = userCard, let mycid = card.cid, let botCard = self.botCard, let metapage = self.metapage else {
            let failure = Failure( message:"Precondition failed" )
            DebugLogger.instance.append(function: "prepareRestClient", failure: failure )
            completion(failure,nil)
            return
        }
        
        if isRestClientReady && tid == nil {
            DebugLogger.instance.append( function:"Skipping prepareRestClient", message:"isRestClientReady=true AND tid is nil" )
            completion(nil,card)
            return
        }
        
        DebugLogger.instance.append( function:"prepareRestClient", message:"tid:\(String(describing: tid)) mycid:\(mycid)" )
        
        // handle race conditions from async call to loadMyPrivateKey()
        let racer = NSObject()
        self.latestRacer = racer
        
        CardHelper.loadMyPrivateKey( mycid, type:Crypto.Types.MODP15 ) {
            failure, privateKey in
            
            if racer != self.latestRacer {
                DebugLogger.instance.append( function:"prepareRestClient LOST RACE", message:"tid:\(String(describing: tid)) mycid:\(mycid)" )
                return;
            }
            
            if let failure = failure {
                ProblemHelper.showProblem( nil, title: "Failed to get your private key".localized, failure: failure )
                completion(failure,nil)
                return
            }
            
            /*let tid:String? = nil    // empty TID, TBD best way to convey none?
            let restClient = BotRestClient( mycid:mycid, privateKey:privateKey, tid:tid, botCard:botCard, metapage:metapage )
            GeneralCache.instance.saveBotRestClient(restClient)
            
            self.botWidget = BotWidget( tid:tid, mycid:mycid, botCard:self.botCard!, scriptMessageHandler:self.scriptMessageHandler )
            self.botWidget?.restClient = restClient
            self.scriptMessageHandler.botWidget = self.botWidget
            self.scriptMessageHandler.secureRequests = true     // re-enable secure requests
             */
            self.botScriptBridge.reset( mycid: mycid, privateKey: privateKey, tid: tid, botCard: botCard, metapage: metapage )
            self.botScriptBridge.secureRequests = true
            self.isRestClientReady = true
            print( "prepareRestClient() complete" );
            
            completion(nil,card)
        }
    }
}
