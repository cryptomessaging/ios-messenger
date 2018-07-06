import UIKit
import EasyTipView

class ThreadHistoryViewController: UITableViewController, OnCardSelectedCallback {
    
    fileprivate var rsvpDialog:UIView?
    fileprivate let threadHistory = ThreadHistoryModel.instance
    
    // bot whobar
    fileprivate var recommendedBotsBar:CardScrollerView<SmallCardView>!
    fileprivate let recommendedBotsViewCell = UITableViewCell()
    
    fileprivate var threadTip:EasyTipView?
    fileprivate var appearing = false
    
    // we've been asked to show a thread after loading
    fileprivate var showThreadTid:String?
    
    fileprivate var createChatProgress:ProgressIndicator?
    
    //
    // MARK: Listen for thread changes
    //
    
    func willEnterForeground() {
        refreshModels()
    }
    
    deinit {
        NotificationHelper.removeObserver(self) // also removes UIApplicationWillEnterForegroundNotification
    }
    
    //
    // MARK: View set up
    //
    
    class func createThreadHistory() -> UIViewController {
        let vc = ThreadHistoryViewController()
        vc.edgesForExtendedLayout = UIRectEdge()
        
        return UINavigationController( rootViewController: vc )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationHelper.addObserver(self, selector: #selector(onMyCardsModelChanged), name: .myCardsModelChanged)
        NotificationHelper.addObserver(self, selector:#selector(onThreadModelChanged), name: .threadModelChanged )
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object:nil)
        
        tableView.register(UINib(nibName: "ThreadHistoryTableViewCell", bundle: nil), forCellReuseIdentifier: ThreadHistoryTableViewCell.TABLE_CELL_IDENTIFIER)
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        let brandIcon = UIImage(named:"Mobido Icon")?.withRenderingMode(.alwaysOriginal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(image:brandIcon, style: .plain, target: self, action: #selector(brandButtonAction))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(createThreadAction))
        navigationItem.title = "Thread History (Title)".localized
        
        tableView.separatorStyle = .none
        
        // setup bot whobar
        recommendedBotsBar = CardScrollerView<SmallCardView>(frame: CGRect( x:0, y:0, width:UIScreen.main.bounds.width, height:SmallCardView.Constants.Height ) )
        recommendedBotsViewCell.contentView.addSubview(recommendedBotsBar)
        recommendedBotsBar.cardSelectedCallback = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        refreshModels()

        RecommendedBotCardsModel.instance.fetchCards {
            failure, cards in
            if let cards = cards {
                let reordered = self.reorderRecommendedCards(cards)
                self.recommendedBotsBar.setCards(reordered, tid:nil)
            }
        }
    }
    
    fileprivate func reorderRecommendedCards(_ cards:[Card]) -> [Card] {
        
        var result = cards
        
        let threads = threadHistory.threads
        let end = threads.count > 20 ? 20 : threads.count
        for i in (0..<end).reversed() {
            let t = threads[i]
            
            // all cards in this thread get pushed to back of list
            if let cids = StringHelper.asArray(t.cids) {
                for c in cids {
                    if let p = CardHelper.findCardIndex(c, inCards: result) {
                        result.append( result.remove(at: p) )
                    }
                }
            }
        }
        
        return result
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .chatHistory, vc:self )
        
        appearing = true
        
        if !self.threadHistory.threads.isEmpty {
            dismissTip()
        } else if let tip = threadTip {
            tip.isHidden = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        appearing = false
        if let tip = threadTip {
            tip.isHidden = true
        }
    }
    
    fileprivate func refreshModels() {
        threadHistory.loadWithProblemReporting(.local, statusCallback:nil, completion:nil )  // make sure it's loaded
        MyCardsModel.instance.loadWithProblemReporting(.local, statusCallback: nil, completion: nil)
    }
    
    func brandButtonAction(_ sender: AnyObject) {
        WebViewController.showWebView(self.navigationController!, htmlFilename: "intro", screenName: .brandIntro )
    }
    
    // Handle tapping on recommended bot or coach
    func onCardSelected(_ sender:NSObject, card:Card, color:UIColor) {
        AnalyticsHelper.trackAction( .tappedRecommendedBot, value:card.nickname! )
        
        let botCard = card
        let nav = self.navigationController!
        
        // do we already have a chat going with just me and this bot?
        for thread in threadHistory.threads {
            if let cids = StringHelper.asArray(thread.cids) { // convert csv to array of strings
                if cids.count == 2 { // assumption is one cid is mine, and one is bots = 2 cids
                    let botindex = cids.index(of:card.cid!)
                    if botindex != nil { // found the bot cid?
                        let othercid = botindex == 0 ? cids[1] : cids[0]
                        if MyCardsModel.instance.isMyCid( cid: othercid ) {
                            // whew! that was a lot of conditions!
                            GroupThreadViewController.showGroupThread( nav, thread: thread )
                            return
                        }
                    }
                }
            }
        }
        
        // If I have exactly one card, create a new chat and bring in bot
        // If I have zero cards, remind them I need a persona, and ask for a nickname
        // If I have more than one card, select the card
        let cards = MyCardsModel.instance.cards
        if cards.count == 0 {
            AlertHelper.showAlert(self, title: "Please Create a Persona (Title)".localized, message: "To start chatting, we need to at least have your nickname".localized, okStyle: .default ) {
                
                EditCardViewController.showCreateCard(nav) {
                    newCard in
                    
                    if let card = newCard {
                        self.createNewChat( myCard:card, botCard:botCard )
                    }
                }
            }
        } else if cards.count == 1 {
            // only one choice, so go with it
            createNewChat( myCard:cards.first!, botCard:botCard )
        } else {
            // select card to use
            let title = String(format:"You Have %d Personas (Title)".localized, cards.count )
            WhichMeViewController.showWhichMePopover(self, cards:cards, title:title, offerCreate: false ) {
                card in
                
                if let card = card {
                    self.createNewChat( myCard:card, botCard:botCard )
                }
            }
        }
    }
    
    // TODO better version, maybe add time, etc.
    fileprivate func createChatSubject(botname:String) -> String {
        let botpos = botname.index(botname.endIndex, offsetBy: -3 )
        let name = botname.substring(to:botpos)
        
        return "\(name) chat"
    }
    
    fileprivate func createNewChat( myCard:Card, botCard:Card ) {
        if createChatProgress != nil {
            // already creating a chat
            return
        }
        
        createChatProgress = ProgressIndicator(parent:view, message:"Creating Chat (Progress)".localized)
        
        let allcids = [ myCard.cid!, botCard.cid! ]
        let subject = createChatSubject(botname: botCard.nickname!)
        ThreadHelper.createPublicChat(hostcid: myCard.cid!, allcids: allcids, subject:subject ) {
            failure, thread in

            if let progress = self.createChatProgress {
                // do this conditionally, in case createNewChat() was called twice
                progress.stop()
                self.createChatProgress = nil
            }
            
            if let failure = failure {
                ProblemHelper.showProblem(nil, title:"Problem creating chat".localized, failure:failure )
            }
            
            if let thread = thread {
                let cached = CachedThread(src:thread)
                self.showGroupThread(cached,botCid:botCard.cid!)
            }
        }
    }
    
    fileprivate func showGroupThread(_ thread:CachedThread, botCid:String ) {
        if let nav = self.navigationController {
            // pop up a bot widget?
            MyUserDefaults.instance.setDefaultWidget(botCid, forThread:thread.tid!)
            
            nav.popToRootViewController(animated: false)
            GroupThreadViewController.showGroupThread( nav, thread: thread )
        }
    }
    
    //
    // MARK: Tool tip
    //
    
    fileprivate func showTapBotTip() {
        UIHelper.delay( UIConstants.TipDelay ) {
            if self.threadTip != nil {  // debounce
                return
            }
            
            if !self.threadHistory.threads.isEmpty { // handle race condition
                return
            }
            
            // make sure there are bots to recommend
            if self.recommendedBotsBar.cards.isEmpty {
                return
            }
            
            if self.appearing {
                self.threadTip = EasyTipView(text: "Tap a bot to start chatting with them".localized)
                self.threadTip?.show(forView: self.recommendedBotsBar, withinSuperview: self.view)
            }
        }
    }
    
    //
    // MARK: Show a group chat
    //
    
    func showThread( _ tid:String ) {

        // find thread matching tid
        for thread in threadHistory.threads {
            if thread.tid == tid {
                // is thread already showing?
                let nav = self.navigationController!
                let top = nav.topViewController
                if let vc = top as? GroupThreadViewController {
                    // showing correct thread?
                    if vc.thread.tid != tid {
                        nav.popToRootViewController(animated: false);
                        GroupThreadViewController.showGroupThread( nav, thread: thread )
                    }
                } else {
                    nav.popToRootViewController(animated: false);
                    GroupThreadViewController.showGroupThread( nav, thread: thread )
                }
                showThreadTid = nil
                return
            }
        }
        
        if threadHistory.state != .serverLoaded {
            // the local cache didn't have the thread, maybe it's new?  Reload threads from server
            showThreadTid = tid
            threadHistory.loadWithProblemReporting(.server, statusCallback: nil, completion: nil)
        } else {
            // Failed to find thread for message, bummer, let 'em know
            //ProblemHelper.showProblem(self, title:"Failed to find chat".localized, message:"The message referred to a chat you are not in".localized )
            DebugLogger.instance.append(function: "THVC.showThread", message:"Failed to find chat" )
        }
    }
    
    //
    // MARK: Load threads from DB
    //
    
    func onMyCardsModelChanged() {
        tableView.reloadData()
    }
    
    func onThreadModelChanged() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
            
            if let rsvpSecret = MyUserDefaults.instance.get(.PENDING_RSVP_SECRET) {
                self.dismissTip()
                RsvpHelper.showRsvpDialog(self, secret: rsvpSecret )
            } else if let tid = self.showThreadTid {
                // we were asked to show a thread after we finish loading, so do it
                self.dismissTip()
                self.showThread(tid)
            } else if self.threadHistory.threads.isEmpty {
                self.showTapBotTip()
            }
        }
    }

    fileprivate func dismissTip() {
        if let tip = threadTip {
            tip.dismiss()
            threadTip = nil
        }
    }

    //
    // MARK: Navigation
    //
    
    func createThreadAction(_ sender: AnyObject) {
        dismissTip()
        
        if MyCardsModel.instance.cards.count == 0 {
            AlertHelper.showAlert(self, title: "Please Create a Persona (Title)".localized, message: "To start chatting, we need to at least have your nickname".localized, okStyle: .default ) {
                EditCardViewController.showCreateCard(self) {
                    newCard in
                    CreateThreadWithBotsViewController.showCreateThread( self.navigationController! )
                }
            }
            return
        }
        
        CreateThreadWithBotsViewController.showCreateThread( self.navigationController! )
    }
    
    //
    // MARK: Section handling
    //
    
    override func tableView(_ tableView: UITableView,
                            heightForRowAt indexPath: IndexPath) -> CGFloat{
        return indexPath.section == 0 ? SmallCardView.Constants.Height : 69
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            let nav = self.navigationController!
            let thread = threadHistory.threads[indexPath.row]
            GroupThreadViewController.showGroupThread(nav, thread: thread)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        switch section {
        case 0:
            return "These Bots Want to Help".localized
        case 1:
            return "Recent".localized
        default:
            // TODO log this situation - it should never happen!
            return "Unknown"
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return threadHistory.threads.count
        default:
            // TODO log this situation - it should never happen!
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            return recommendedBotsViewCell
        case 1:
            return recycleCell(threadHistory.threads, indexPath:indexPath)
        default:
            return UITableViewCell()    // Forced to return a value?!  (I dont want to throw an exception)
        }
    }
    
    fileprivate func recycleCell(_ array:[CachedThread], indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThreadHistoryTableViewCell.TABLE_CELL_IDENTIFIER, for: indexPath) as! ThreadHistoryTableViewCell

        let thread = array[indexPath.row]
        cell.refresh( thread )
        
        return cell
    }
}
