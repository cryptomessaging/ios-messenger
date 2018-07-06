import UIKit

// The work area in the upper half of the messenger during a chat/thread
// contains:
//     toolbar - list of bots and other tools
//     widget: headliners/cards
//     widget: bots...
open class ThreadWorkspaceView: UIStackView, OnCardSelectedCallback, BotScriptDelegate {
    
    static let DEBUG = false
    
    fileprivate let DEFAULT_MIN_CHAT_HEIGHT:CGFloat = 50
    
    weak var vc:UIViewController? {
        didSet {
            botWidgetView.vc = vc
        }
    }
    
    fileprivate var keyboardHeight:CGFloat = 0
    fileprivate var chatInputBarHeight:CGFloat = 0
    fileprivate let statusBarHeight:CGFloat = 20
    fileprivate let navigationBarHeight:CGFloat = 44
    fileprivate var isCreatingChatMessage = false
    
    fileprivate var minChatHeight:CGFloat = 0  // this goes to ZERO when bot widget uses keyboard
    fileprivate var requestedBotWidgetHeight:CGFloat = 0
    
    let whoBar = CardScrollerView<SmallCardView>(frame: CGRect.zero )
    
    fileprivate let botWidgetView = BotWidgetView( frame: CGRect.zero )
    fileprivate var botHeightConstraint:NSLayoutConstraint?
    
    fileprivate var thread:CachedThread?
    var chatDataSource:ChatDataSource?
    fileprivate var mycid:String?   // this may be nil if I've left the chat, or for a short time after
                                    // the chat is created if the user is choosing one of many to use
    
    var showBotWidgetOnStart:String?    // cid
    
    //
    // MARK: init
    //
    
    required public init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame:frame)
        commonInit()
    }
    
    fileprivate func commonInit() {
        self.autoresizingMask = UIViewAutoresizing()
        self.translatesAutoresizingMaskIntoConstraints = false
        self.axis = .vertical
        self.distribution = .fill
        self.alignment = .center
        self.spacing = 0
        
        addArrangedSubview( whoBar )
        setConstraints( whoBar, height:SmallCardView().cellSize().height )
        whoBar.cardSelectedCallback = self
        
        addSubview( botWidgetView )
        botHeightConstraint = setConstraints( botWidgetView, height:UIConstants.RowHeight )
        botWidgetView.isHidden = true
        botWidgetView.delegate = self  // register to get height callback, etc.
        
        NotificationHelper.addObserver(self, selector: #selector(onThreadDbChanged), name: .threadDbChanged )
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        nc.addObserver(self, selector: #selector(keyboardDidHide), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
        nc.addObserver(self, selector: #selector(chatInputBarHeightChange), name: NSNotification.Name(rawValue: MyChatInputBar.NotificationName.HeightChange.rawValue), object: nil)
        nc.addObserver(self, selector: #selector(chatInputBeginEditing), name: NSNotification.Name(rawValue: MyChatInputBar.NotificationName.BeginEditing.rawValue), object: nil)
        nc.addObserver(self, selector: #selector(chatInputEndEditing), name: NSNotification.Name(rawValue: MyChatInputBar.NotificationName.EndEditing.rawValue), object: nil)
    }
    
    deinit {
        NotificationHelper.removeObserver(self)
    }
    
    //
    // As keyboard appears and disappears, make sure the right amount
    // of chat messages are showing
    //
    
    func keyboardWillShow(_ notification:Notification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        if self.keyboardHeight != keyboardRectangle.height {
            self.keyboardHeight = keyboardRectangle.height
            setBotWidgetHeight(requestedBotWidgetHeight)
        }
    }
    
    func keyboardDidHide(_ notification:Notification) {
        self.keyboardHeight = 0
        setBotWidgetHeight(requestedBotWidgetHeight)
    }
    
    func chatInputBarHeightChange(_ notification:Notification) {
        if let height = notification.object as? CGFloat {
            if height != chatInputBarHeight {
                self.chatInputBarHeight = height
                setBotWidgetHeight(requestedBotWidgetHeight)
            }
        }
    }
    
    func chatInputBeginEditing(_ notification:Notification) {
        self.minChatHeight = DEFAULT_MIN_CHAT_HEIGHT
        self.isCreatingChatMessage = true
        setBotWidgetHeight(requestedBotWidgetHeight)
    }
    
    func chatInputEndEditing(_ notification:Notification) {
        self.minChatHeight = 0
        self.isCreatingChatMessage = false
        setBotWidgetHeight(requestedBotWidgetHeight)
    }
    
    // called when threads summary info has changed locally (i.e. subject, cids, etc.), usually a card added or removed
    func onThreadDbChanged() {
        if let tid = self.thread?.tid {
            if let thread = ChatDatabase.instance.getThread(tid) {
                let mycid = self.mycid
                
                UIHelper.onMainThread {
                    self.reset(thread, mycid:mycid )
                }
            }
        }
    }
    
    //
    // MARK: BotWidgetCallbackHandler
    //
    
    func doSetBackButton( _ options:BackButtonOptions? ) {
        // ignored TBD
    }
    
    func doSetupScreen( _ options:ScreenOptions ) {
        // ignored TBD
    }
    
    func doSetOptionButtonItems( _ items:[OptionItem] ) {
        botWidgetView.optionButton.items = items
    }
    
    func doBotWidgetHeightChange(_ height:CGFloat) {
        setBotWidgetHeight(height)
    }
    
    func fetchThreadCards() -> [Card]? {
        return whoBar.cards
    }
    
    func doSelectUserCard( options:SelectUserCardOptions?, completion:@escaping( _ failure:Failure?, _ card:Card?) -> Void ) -> Void {
        // ignored TBD
    }
    
    func doEnsureExclusiveChat( subject:String?, updateRestClient:Bool, _ completion:@escaping( _ failure:Failure?, _ thread:ChatThread?) -> Void ) -> Void {
        // TODO ignore?  implement?  TBD
    }
    
    func doShowChat( _ options:ShowChatOptions ) {
        if let tid = options.tid {
            NotificationHelper.signalShowChat( tid );
        }
    }
    
    func fetchUserCard() -> Card? {
        return CardHelper.findCard(mycid, inCards: whoBar.cards)
    }
    
    func fetchBotCard() -> Card? {
        return botWidgetView.botCard
    }
    
    func fetchThread() -> ChatThread? {
        if let thread = thread {
            return ChatThread( cached: thread )
        } else {
            return nil
        }
    }
    
    func fetchThreadList( _ tids:[String] ) -> ThreadListResult {

        // for now, rely on local thread cache and don't dip into server on misses 
        // TODO fallback to server
        let db = ChatDatabase.instance
        var found = [CachedThread]()
        var missing = [String]()
        for id in tids {
            if let thread = db.getThread(id) {
                thread.msg = nil
                thread.cids = nil   // Hide cids?  Is this a security leak?
                found.append(thread)
            } else {
                missing.append(id)
            }
        }
        
        let result = ThreadListResult()
        result.found = found
        result.missing = missing
        return result
    }
    
    // TODO get all messages, or first 100, or...
    // For now it just gets the messages in the current buffer
    func fetchMessageHistory() -> [ChatMessage]? {
        var result = [ChatMessage]()
        if let chatItems = chatDataSource?.chatItems {
            for i in chatItems {
                result.append( (i as! ChatItem).msg )
                /* for now just handle text messages
                if let textMessage = i as? TextMessage {
                    let msg = ChatMessage()
                    msg.from = textMessage.cid
                    msg.body = textMessage.text
                    msg.created = TimeHelper.as8601( textMessage.date )
                    
                    result.append( msg )
                }*/
            }
        }
        
        return result
    }
    
    func doEnvironmentFixup( _ env:inout WidgetEnvironment ) {
    }
    
    func doCloseBotWidget() {
        // ignored/not supported?  Or should we...?
    }

    //
    // MARK: Utility
    //
    
    // pin to sides, and give fixed height
    @discardableResult fileprivate func setConstraints( _ view:UIView, height:CGFloat ) -> NSLayoutConstraint {
        // give us a fixed height for now
        let heightConstraint = NSLayoutConstraint(item: view, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: height)
        addConstraint(heightConstraint)
        
        // expand workspace to both sides
        addConstraint(NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 0))
        //addConstraint(NSLayoutConstraint(item: view, attribute: .Trailing, relatedBy: .Equal, toItem: self, attribute: .Trailing, multiplier: 1, constant: 0))
        
        return heightConstraint
    }
    
    //
    // MARK: set thread and cards
    //
    
    func reset(_ thread:CachedThread, mycid:String? ) {
        if ThreadWorkspaceView.DEBUG {
            print( "Resetting thread", thread.cids ?? "with no cids", mycid ?? "with no mycid" )
        }
        self.thread = thread
        self.mycid = mycid  // might be nil!!
        
        // load cards from thread for display (in background)
        guard let cidList = StringHelper.asArray(thread.cids) else {
            return  // no cids to work with, wierd?!
        }
        
        // Was a widget showing last time we saw this thread?  Then re-open it...
        let tid = thread.tid!
        if showBotWidgetOnStart == nil {
            if let defaultWidgetCid = MyUserDefaults.instance.getDefaultWidget(tid) {
                // is widget still in list?
                if cidList.contains( defaultWidgetCid ) {
                    showBotWidgetOnStart = defaultWidgetCid
                } else {
                    MyUserDefaults.instance.removeDefaultWidget(tid)
                }
            }
        }
        
        UIHelper.onMainThread {
            // update whobar cards...
            var updated = self.whoBar.cards
            
            // remove any cards not in new cidList
            for i in (0..<updated.count).reversed() {
                if !cidList.contains(updated[i].cid!) {
                    updated.remove(at: i)
                }
            }

            for cid in cidList {
                CardHelper.fetchThreadCard(tid, cid:cid) { card in
                    // update list in main thread, as they come in
                    UIHelper.onMainThread {
                        // if the card is already in list, update in place
                        if let index = CardHelper.findCardIndex( card.cid, inCards:updated ) {
                            updated[index] = card
                            self.whoBar.setCards(updated, tid:tid)
                            self.fixupWidgetSidebarColor()
                            return
                        }
                        
                        // this is a new card in list
                        if( card.isBot() ) {
                            updated.insert( card, at: 0 )    // bots go in front
                        } else {
                            updated.append( card )
                        }
                        self.whoBar.setCards(updated, tid:tid)
                        self.fixupWidgetSidebarColor()
                        
                        // show this bots widget? (make sure it's not already showing)
                        if card.cid == self.showBotWidgetOnStart && card.cid != self.botWidgetCid() {
                            let color = self.whoBar.getCardColor(card)
                            self.changeBotWidget(card, color:color)
                            
                            // only do this once
                            self.showBotWidgetOnStart = nil
                        }
                    }
                }
            }
            
            // if the bot currently hosting the bot widget has been removed, reset the widget
            if let botcid = self.botWidgetCid() {
                if !cidList.contains( botcid ) {
                    UIHelper.onMainThread {
                        self.botWidgetView.reset()
                        if !self.botWidgetView.isHidden {
                            self.hideRow(self.botWidgetView)
                        }
                    }
                } else {
                    // make sure the bot widget sidebar is the right color
                    self.fixupWidgetSidebarColor()
                }
            }
        }
    }
    
    //
    // MARK: Options
    //
    
    func addBotOptions(_ vc:UIViewController, alert:UIAlertController) {
    }
    
    func fixupWidgetSidebarColor() {
        if let card = botWidgetView.botCard {
            let color = whoBar.getCardColor(card)
            botWidgetView.reset( color )
        }
    }
    
    //
    // MARK: Handle card selections
    //
    
    // whobar card selected
    func onCardSelected(_ sender:NSObject, card:Card, color:UIColor) {
        if card.isBot() {
            changeBotWidget(card, color:color)
        } else {
            // user card selected, so show full card detail
            let nav = self.vc!.navigationController!
            FullCard2ViewController.showFullCardView( nav, card:card, tid:thread!.tid!, mycid:self.mycid )
        }
    }
    
    fileprivate func changeBotWidget(_ botCard:Card, color:UIColor) {
        if botCard.cid == botWidgetCid() {
            // the card is correct, so just figure out visibility
            if botWidgetView.isHidden {
                showRow(botWidgetView)
                whoBar.setSelectedCardId(botCard.cid)
            } else {
                if let tid = thread?.tid {
                    MyUserDefaults.instance.removeDefaultWidget(tid)
                }
                hideRow(botWidgetView)
                whoBar.setSelectedCardId(nil)
            }
        } else {
            // set new card and make sure its showing
            setBotWidgetHeight(UIConstants.DefaultBotWidgetHeight)
            MyUserDefaults.instance.setDefaultWidget(botCard.cid, forThread:thread!.tid!)
            botWidgetView.reset( thread!.tid!, mycid:mycid, botCard: botCard, color:color )
            showRow(botWidgetView)
            whoBar.setSelectedCardId(botCard.cid)
        }
    }
    
    //
    // MARK: Utility
    //
    
    fileprivate func hideRow(_ view:UIView) {
        view.isHidden = true
        removeArrangedSubview(view)
    }
    
    fileprivate func showRow(_ view:UIView) {
        view.isHidden = false
        addArrangedSubview(view)
    }
    
    fileprivate func setBotWidgetHeight(_ height:CGFloat) {
        self.requestedBotWidgetHeight = height  // remember how much they asked for, so we can scale back up
        
        // minus: status bar, nav bar, whobar, chat input bar, keyboard
        var others = statusBarHeight + navigationBarHeight + whoBar.frame.height + keyboardHeight
        if isCreatingChatMessage {
            others += chatInputBarHeight
        }

        // remaining is the space left over for chat messages and the bot widget
        let screenHeight = UIScreen.main.bounds.height
        let remaining = screenHeight - others
        
        // guarantee at least 40px for chat messages
        let maxWidgetHeight = remaining - minChatHeight
        
        let newHeight = height > maxWidgetHeight ? maxWidgetHeight : height
        UIHelper.onMainThread {
            self.botHeightConstraint?.constant = newHeight
            self.setNeedsUpdateConstraints()
        }
    }
    
    fileprivate func botWidgetCid() -> String? {
        if let card = botWidgetView.botCard {
            return card.cid
        } else {
            return nil
        }
    }
}
