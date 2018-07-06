import UIKit
import Chatto
import WebKit

class ChatMessageInteractionHandler: BaseMessageInteractionHandlerProtocol {
    
    fileprivate weak var vc:UIViewController!
    fileprivate var thread:CachedThread?
    fileprivate var mycid:String?
    fileprivate weak var alert:UIAlertController?   // hack to debounce multiple long press gestures
    
    func userDidTapOnFailIcon(_ chatItem: ChatItemProtocol) {}
    func userDidTapOnBubble(_ chatItem: ChatItemProtocol) {}
    
    func userDidTapOnChatHead(_ chatItem: ChatItemProtocol) {
        guard let item = chatItem as? ChatItem else {
            return
        }
        let cid = item.msg.from!
        let tid = thread!.tid!
        CardHelper.fetchThreadCard(tid, cid: cid ) {
            card in
            
            let nav = self.vc.navigationController!
            FullCard2ViewController.showFullCardView( nav, card:card, tid:tid, mycid:self.mycid )
        }
    }
    
    func userDidLongPressOnBubble(_ chatItem: ChatItemProtocol, view: UIView) {
        guard let item = chatItem as? ChatItem else {
            return
        }
        
        // handle double taps
        if self.alert != nil  {
            return
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        // can we delete this message?
        if item.msg.from == mycid {
            let deleteAction = UIAlertAction(title: "Delete message".localized, style: .default, handler: {
                action in

                self.alert = nil
            
                // compound id: tid/created/cid
                let messages = DeleteChatMessages()
                messages.tid = self.thread!.tid!
                messages.cid = self.mycid!
                //let created = TimeHelper.as8601Millis(item.date)
                messages.timestamps = [item.msg.created!]
            
                let progress = ProgressIndicator(parent: view, message: "Deleting Message".localized )
                MobidoRestClient.instance.deleteMessages(messages) {
                    result in
                
                    if !ProblemHelper.showProblem( self.vc, title: "Problem deleting message".localized, failure: result.failure ) {
                        // proactively, update local database
                        ChatDatabase.instance.removeMessages(messages.tid!,timestamps: messages.timestamps!)
                    }
                
                    progress.stop()
                }
            })
            alert.addAction(deleteAction)
        }
        
        let flagAction = UIAlertAction(title: "Flag as inappropriate".localized, style: .default, handler: {
            action in
            
            self.alert = nil
            
            // compound id: tid/created/cid
            let created = item.msg.created! // TimeHelper.as8601(msg.date)
            let id = "\(self.thread!.tid!)/\(created)/\(String(describing: item.msg.from))"
            if let nav = self.vc.navigationController {
                ContentFlaggerViewController.showContentFlagger(nav, type: .ThreadMessage, id: id )
            }
        })
        alert.addAction(flagAction)

        UIHelper.ipadFixup( alert, view:view ) {
            uiaa in
            self.alert = nil
        }
        
        vc.present( alert, animated: true, completion:nil )
        self.alert = alert
    }
}

struct GroupThreadViewGlobals {
    static var currentTid:String?
}

class GroupThreadViewController: BaseChatViewController, WKNavigationDelegate, MyChatInputBarDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ChatDataSourceUpdateListener, AddHandler {
    
    static let DEBUG = false
    
    fileprivate var shareButton:UIBarButtonItem!
    fileprivate let workspace = ThreadWorkspaceView(frame: CGRect.zero)
    fileprivate let dataSource:ChatDataSource = ChatDataSource()
    fileprivate let messageSender:MessageSender = MessageSender()
    fileprivate let chatInputView = MyChatInputBar.create()
    
    let imagePickerController = UIImagePickerController()
    
    fileprivate var mycid:String?   // my voice in this conversation
    fileprivate(set) var thread:CachedThread!
    fileprivate var addPeopleTipShown = false
    
    fileprivate let interactionHandler = ChatMessageInteractionHandler()
    
    var doFilterPII = false  // optimist, but check accessKey.acm
    
    //
    // MARK: Startup helper
    //
    
    @discardableResult class func showGroupThread(_ nav:UINavigationController, thread:CachedThread ) -> GroupThreadViewController {
        
        let vc = GroupThreadViewController()
        vc.thread = thread
        vc.hidesBottomBarWhenPushed = true
        
        // which card am I?
        let myCardIds = MyCardsModel.instance.cardIds
        let threadCardIds = CardHelper.getThreadCardIds(thread)
        let common = myCardIds.intersection(threadCardIds)
        
        if common.isEmpty {
            //parent.present( vc /*UINavigationController(rootViewController: vc)*/, animated:true )
            //return vc
            nav.pushViewController(vc, animated: true)
        } else if common.count == 1 {
            vc.mycid = common.first!
            //parent.present( vc /*UINavigationController(rootViewController: vc)*/, animated:true )
            //return vc
            nav.pushViewController(vc, animated: true)
        } else {
            let cards = CardHelper.findCards(common, inCards:MyCardsModel.instance.cards )
            let title = String(format:"You Have %d Personas In This Chat (Title)".localized, cards.count )
            WhichMeViewController.showWhichMePopover(nav, cards:cards, title:title, offerCreate: false ) {
                card in // null = cancel
                
                if let card = card {
                    vc.mycid = card.cid
                    nav.pushViewController(vc, animated: true)
                }
            }
        }
        
        return vc
    }
    
    func showBotWidgetOnStart( _ cid:String? ) {
        workspace.showBotWidgetOnStart = cid;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        workspace.vc = self
        interactionHandler.vc = self
        self.title = thread.subject

        dataSource.reset(thread, mycid:mycid)
        messageSender.reset(thread.tid!)
        workspace.reset(thread, mycid:mycid )
        
        interactionHandler.thread = thread
        interactionHandler.mycid = mycid
        
        // am I the only one?
        if let cids = StringHelper.asArray(thread.cids) {
            if cids.count == 1 {
                //showAddPeopleTip()
            }
        }
        
        edgesForExtendedLayout = UIRectEdge()
        navigationItem.leftBarButtonItem = UIBarButtonItem( title: "Back".localized, style: .plain, target:self, action: #selector(backButtonAction))
        
        shareButton = UIBarButtonItem(image: UIImage(named: "Invite People"), style: UIBarButtonItemStyle.plain, target:self, action:#selector(shareButtonAction) )
        let moreButton = UIBarButtonItem(image: UIImage(named: "More Vertical"), style: UIBarButtonItemStyle.plain, target:self, action:#selector(moreButtonAction) )
        navigationItem.rightBarButtonItems = [ moreButton, shareButton ]
        
        shareButton.isEnabled = mycid != nil
        
        if GroupThreadViewController.DEBUG { print( "GroupThreadViewController.viewDidLoad()" ) }
        
        // do this BEFORE sync since most of the time local cache is fine
        self.chatDataSource = dataSource
        dataSource.updateListener = self
        
        self.chatItemsDecorator = MyChatItemsDecorator()
        
        SyncHelper.syncChatMessages( getTid() ) {
            result in
            
            // if there are new messages...
            if result == .newMessages {
                // scroll to bottom after small delay
                UIHelper.delay( 0.5 ) {
                    self.scrollToBottom(animated: true )
                }
            } else if result == .chatDeleted {
                self.mycid = nil
                self.shareButton.isEnabled = false
            }
        }
        
        // very light gray background... or an image TODO
        view.backgroundColor = UIConstants.LightGrayBackground
        
        // add in the bot/chathead workspace
        addWorkspace()
        workspace.chatDataSource = dataSource
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePickerController.sourceType = .camera
            imagePickerController.cameraCaptureMode = .photo
            imagePickerController.modalPresentationStyle = .overCurrentContext
            imagePickerController.delegate = self
        }
        
        // filter PII?
        if let ak = MyUserDefaults.instance.getAccessKey(), let acm = ak.acm {
            doFilterPII = acm["pii"] == "filter"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .chat, vc:self )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if GroupThreadViewController.DEBUG { print( "GroupThreadViewController.viewWillAppear" ) }
        GroupThreadViewGlobals.currentTid = self.thread.tid
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if GroupThreadViewController.DEBUG { print( "GroupThreadViewController.viewWillDisappear" ) }
        GroupThreadViewGlobals.currentTid = nil
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        chatInputView.setNeedsLayout()
    }
    
    override func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
        return [
            TextMessage.Constant.ItemType: [ TextMessagePresenterBuilder(interactionHandler: interactionHandler) ],
            PhotoMessage.Constant.ItemType: [ PhotoMessagePresenterBuilder(interactionHandler: interactionHandler) ]
        ]
    }
    
    fileprivate func addWorkspace() {
        self.view.addSubview( workspace )
        
        // top of workspace is top of window
        view.addConstraint(NSLayoutConstraint(item: workspace, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0))
        
        // expand to workspace to both sides
        view.addConstraint(NSLayoutConstraint(item: workspace, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: workspace, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0))
        
        // Remove constraint for top of collectionview...
        // looking for NSLayoutConstraint(item: self.view, attribute: .Top, relatedBy: .Equal, toItem: self.collectionView, attribute: .Top, multiplier: 1, constant: 0))
        for c in view.constraints {
            let item = c.firstItem as? NSObject
            let toItem = c.secondItem as? NSObject
            if item == self.view && c.firstAttribute == .top && c.relation == .equal && toItem == self.collectionView && c.secondAttribute == .top {
                c.isActive = false    // remove() is going to be deprecated
            }
        }

        // ...and set bottom of my workspace is top of collectionview
        view.addConstraint(NSLayoutConstraint(item: workspace, attribute: .bottom, relatedBy: .equal, toItem: collectionView, attribute: .top, multiplier: 1, constant: 0))
    }
    
    override func createChatInputView() -> UIView {
        chatInputView.delegate = self
        return chatInputView
    }
    
    //
    // MARK: Tool tip
    //
    
    /*
    private func showAddPeopleTip() {
        if addPeopleTipShown {
            return
        }
        
        EasyTipView.show(animated: true,
                         forItem: shareButton,
                         //withinSuperview: shareButton.parent
                         text: "Click here to add people".localized )
        addPeopleTipShown = true
    }*/
    
    //
    // MARK: Navigation/actions
    //
    
    func inputBarSendButtonPressed(_ message:String) {
        if myCidMissing() {
            return
        }
        
        if let text = StringHelper.clean(message) {
            let msg = ChatMessage()
            msg.from = mycid!
            msg.body = text
            msg.created = TimeHelper.nowAs8601()
            // tid is set by message sender
            
            messageSender.sendMessage(msg, image:nil)    // puts in local db and sends to chat server
        }
    }
    
    func backButtonAction(_ sender: UIBarButtonItem) {
        unwind()
    }
    
    func moreButtonAction(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let isInThread = mycid != nil   // is a member of this thread?
        
        let renameAction = UIAlertAction(title: "Rename chat".localized, style: .default, handler: {
            action in
            self.renameThread()
        })
        renameAction.isEnabled = isInThread
        alert.addAction( renameAction )
        
        let leaveTitle = isInThread ? "Leave chat".localized : "Forget chat".localized
        let leaveAction = UIAlertAction(title: leaveTitle, style: .default, handler: {
            action in
            self.confirmLeaveThread()
        })
        alert.addAction( leaveAction )
        
        let deleteAction = UIAlertAction(title: "Delete chat".localized, style: .default, handler: {
            action in
            self.confirmDeleteThread()
        })
        deleteAction.isEnabled = isInThread // TODO check if I'm a host
        alert.addAction(deleteAction)
        
        workspace.addBotOptions(self, alert:alert)
        
        let flagAction = UIAlertAction(title: "Flag as inappropriate".localized, style: .destructive, handler: {
            action in
            let nav = self.navigationController!
            let tid = (self.thread.tid)!
            ContentFlaggerViewController.showContentFlagger(nav, type: .Thread, id: tid )
        })
        flagAction.isEnabled = isInThread // Can't flag what I'm not in ;)
        alert.addAction(flagAction)
        
        UIHelper.ipadFixup( alert, barButtonItem: sender )
        present(alert, animated: true, completion: nil)
        AnalyticsHelper.trackPopover( .widgetOptions, vc:alert )
    }
    
    func confirmDeleteThread() {
        let alert = UIAlertController(title: "Delete chat?".localized, message: "This deletes the chat for EVERYONE.  It cannot be undone.".localized, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            self.deleteThread()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func confirmLeaveThread() {
        let isInThread = mycid != nil
        let title = isInThread ? "Leave chat?".localized : "Forget chat?".localized
        let message = isInThread ? "If you leave, you will need to be invited back".localized : "You are viewing a local copy of a chat you have already left.  This will delete the local copy of the messages".localized
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            self.leaveThread()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func renameThread() {
        let alert = UIAlertController(title: "Rename chat".localized, message: nil, preferredStyle: .alert )

        alert.addTextField {
            field in
            field.text = self.thread.subject
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            if let subject = StringHelper.clean( alert.textFields!.first!.text ) {
                self.updateThreadSubject(subject)
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    func updateThreadSubject(_ subject:String) {
        let progress = ProgressIndicator(parent: view, message: "Changing title (Progress)".localized )
        
        let tid = getTid()
        MobidoRestClient.instance.renameThread( RenameChat(tid:tid, cid:mycid!, subject:subject) ) {
            result in
            
            progress.stop()
            if !ProblemHelper.showProblem(self, title: "Failed to update title (Title)", failure: result.failure ) {
                self.title = subject
                self.thread.subject = subject
                do {
                    try ChatDatabase.instance.updateThreadSubject(tid, subject: subject)
                } catch {
                    // shouldn't happen, but we can carry on; Server should ping us back with an update message
                    DebugLogger.instance.append(function: "updateThreadSubject()", error: error)
                }
            }
        }
    }
    
    //
    // MARK: Share link
    //
    
    func shareButtonAction(_ sender: UIBarButtonItem) {
        if let mycard = CardHelper.findCard(mycid, inCards: MyCardsModel.instance.cards ) {
            AddToChatViewController.showAddToChat(self.navigationController!, mycard:mycard, thread:thread, addHandler:self )
        } else {
            ProblemHelper.showProblem(self, title: "Failed to find your card (Title)".localized, failure: Failure(message:"Your card was not available".localized) )
        }
    }
    
    //
    // MARK: Leave thread
    //
    
    fileprivate func leaveThread() {
        let isInThread = mycid != nil
        let message = isInThread ? "Leaving".localized : "Forgetting".localized
        let progress = ProgressIndicator(parent: view, message: message )
        
        let tid = getTid()
        MobidoRestClient.instance.leaveThread(tid, mycid: mycid) {
            result in
            
            // also clean up local db
            ChatDatabase.instance.removeThread(tid)
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                // success?
                if let failure = result.failure {
                    if failure.statusCode != 410 {
                        let title = isInThread ? "Failed to leave chat".localized : "Failed to forget chat".localized
                        ProblemHelper.showProblem(self, title:title, failure:failure )
                        return
                    }
                }

                // success!
                AnalyticsHelper.trackResult(.chatLeft)
                self.unwind()
            })
        }
    }
    
    fileprivate func forgetThread() {
        let tid = getTid()
        ChatDatabase.instance.removeThread(tid)
        AnalyticsHelper.trackResult(.chatForgotten)
        unwind()
    }
    
    //
    // MARK: Delete thread
    //
    
    fileprivate func deleteThread() {
        let progress = ProgressIndicator(parent: view, message: "Deleting".localized )
        
        let tid = getTid()
        MobidoRestClient.instance.deleteThread(tid) {
            result in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                // success?
                if let failure = result.failure {
                    ProblemHelper.showProblem(self, title: "Failed to delete chat".localized, failure:failure )
                } else {
                    // success!
                    // TODO ChatDatabase.instance.deleteThread(tid) // we still will get a delete message from server
                    //self.performSegueWithIdentifier("exitThreadSegue", sender: self)
                    
                    AnalyticsHelper.trackResult(.chatDeleted)
                    self.unwind()
                }
            })
        }
    }
    
    //
    // MARK: Utility
    //
    
    fileprivate func unwind() {
        //dismiss(animated: true, completion: nil)
        navigationController?.popViewController(animated: true)
    }
    
    fileprivate func myCidMissing() -> Bool {
        if mycid == nil {
            ProblemHelper.showProblem( self, title: "Not in chat".localized, message: "You are not a member of this chat anymore".localized, code: 0 )
            return true
        } else {
            return false
        }
    }
    
    fileprivate func getTid() -> String {
        return thread.tid!
    }
    
    //
    // MARK: Capture image support
    //
    
    func inputBarCameraButtonPressed() {
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            AlertHelper.showOkAlert(self, title: "No Camera Available (Alert Title)".localized, message: "This device does not have a camera".localized, okAction: nil)
            return
        }
        
        if doFilterPII {
            AlertHelper.showOkAlert(self, title: "No Pictures Allowed (Alert Title)".localized, message: "We cannot allow pictures until your parent signs the consent form".localized, okAction: nil)
            return
        }
        
        if myCidMissing() {
            return
        }
        
        present(imagePickerController, animated: true, completion: nil )
    }
    
    //
    // MARK: UIImagePickerControllerDelegate
    //
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        // use same 'image' var so garbage collection can happen if it needs
        var image = info[UIImagePickerControllerOriginalImage] as! UIImage
        image = ImageHelper.resizeImage(image,minSide:1000)   // reduce the size a bit, TODO even smaller 640x480?
        
        // convert to JPEG
        let jpeg = UIImageJPEGRepresentation(image, 1.0 )
        let base64 = jpeg!.base64EncodedString(options: NSData.Base64EncodingOptions.lineLength76Characters)
        
        let media = Media()
        media.type = "image/jpeg;base64"
        media.src = base64
        let now = TimeHelper.nowAs8601()
        media.meta = [ "width": String(describing: Int(image.size.width)),  // hints of full size (server should really confirm)
                       "height": String(describing: Int(image.size.height)),
                       "created": now ]     // used by chat presenter to know if two messages are the same, even though
                                            // msg.created might have been changed by the server

        let msg = ChatMessage()
        msg.from = mycid!
        msg.created = now
        msg.media = [ media ]
        
        scrollToBottomOnNextUpdate = true
        messageSender.sendMessage(msg, image:image)    // puts in local db and sends to chat server
        dismiss(animated: true, completion: nil)
    }
    
    // after adding a photomessage, scroll to bottom of messages
    var scrollToBottomOnNextUpdate = false
    func onChatDataSourceUpdate( _ source: ChatDataSource ) {
        if scrollToBottomOnNextUpdate {
            scrollToBottomOnNextUpdate = false
            UIHelper.delay( 0.2 ) {
                self.scrollToBottom(animated: true )
            }
        }
    }
    
    //
    // Add bots/coaches/existing contacts to this thread
    //
    
    func addBot(_ vc:UIViewController, botcard:Card, completion:@escaping (_ success:Bool)->Void ) {
        // sanity check... is bot already in toolbar?
        if CardHelper.findCard(botcard.cid!, inCards: workspace.whoBar.cards ) != nil {
            // already in toolbar, so nothing more to do...
            completion(true)
            return
        }
        
        let progress = ProgressIndicator(parent:vc.view, message:"Adding bot (Progress)".localized)
        MobidoRestClient.instance.addCardToThread(botcard.cid!, tid:thread.tid!, mycid:mycid! ) {
            result in
            
            if let card = result.card {
                // cache for later
                LruCache.instance.saveCard(card)
            }
            
            UIHelper.onMainThread {
                progress.stop()
                if let failure = result.failure {
                    ProblemHelper.showProblem(vc, title:"Problem adding bot".localized, failure:failure )
                    completion(false)
                } else if let card = result.card {
                    // optimistically update our whobar cards
                    let color = self.workspace.whoBar.addCard( card )
                    self.workspace.fixupWidgetSidebarColor()
                    self.workspace.onCardSelected(self, card:botcard, color:color) // show widget for new card
                    AnalyticsHelper.trackResult(.botAdded)
                    completion(true)
                }
            }
        }
    }
    
    func addCoach( _ vc:UIViewController, cid:String, completion:@escaping(_ success:Bool)->Void ) {
        // sanity check... is bot already in toolbar?
        if CardHelper.findCard(cid, inCards: workspace.whoBar.cards ) != nil {
            // already in toolbar, so nothing more to do...
            completion(true)
            return
        }
        
        let progress = ProgressIndicator(parent:vc.view, message:"Adding coach (Progress)".localized)
        MobidoRestClient.instance.addCardToThread(cid,tid: thread.tid!, mycid:mycid! ) {
            result in
            
            if let card = result.card {
                // cache for later
                LruCache.instance.saveCard(card)
            }
            
            UIHelper.onMainThread {
                progress.stop()
                if let failure = result.failure {
                    ProblemHelper.showProblem(vc, title:"Problem adding coach".localized, failure:failure )
                    completion(false)
                } else if let card = result.card {
                    // optimistically update our whobar cards
                    self.workspace.whoBar.addCard( card )
                    self.workspace.fixupWidgetSidebarColor()
                    AnalyticsHelper.trackResult(.coachAdded)
                    completion(true)
                }
            }
        }
    }
    
    func addContacts( _ vc:UIViewController, contactList:[ChatContact], completion:@escaping(_ success:Bool)->Void ) {
        // sanity check... remove any people in list already in the thread
        var addlist = [ChatContact]()
        for contact in contactList {
            if CardHelper.findCard(contact.cid, inCards: workspace.whoBar.cards ) == nil {
                // card wasnt in existing list, so add
                addlist.append( contact )
            }
        }
        
        let progress = ProgressIndicator(parent:vc.view, message:"Adding contacts (Progress)".localized)
        let add = AddContacts()
        add.mycid = mycid!
        add.contacts = addlist
        MobidoRestClient.instance.addContactsToThread( add, tid:thread.tid! ) {
            result in
            
            if let added = result.cards {
                for card in added {
                    // cache for later
                    LruCache.instance.saveCard(card)
                }
            }
            
            UIHelper.onMainThread {
                progress.stop()
                
                // This is an unusual request, as it can complete with partial success and partial failure.  So
                // handle both!
                
                if let added = result.cards {
                    for card in added {
                        // optimistically update our whobar cards
                        self.workspace.whoBar.addCard( card )
                        self.workspace.fixupWidgetSidebarColor()
                    }
                    AnalyticsHelper.trackResult(.contactsAdded)
                }
                
                if let failure = result.failure {
                    ProblemHelper.showProblem(vc, title:"Problem adding contacts".localized, failure:failure )
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
}
