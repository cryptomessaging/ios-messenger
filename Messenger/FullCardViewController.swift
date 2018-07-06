import Foundation
import UIKit

class FullCard2ViewController: UIViewController {
    
    fileprivate var card:Card!
    fileprivate var tid:String? // we always need context, unless its our own card
    fileprivate var mycid:String?
    
    fileprivate var fullCardView:FullCardView?
    
    fileprivate var chatButton:UIBarButtonItem!
    
    //
    // MARK: Navigation helper
    //
    
    class func showFullCardView( _ nav:UINavigationController, card:Card, tid:String?, mycid:String? ) {
        let vc = FullCard2ViewController()
        vc.card = card
        vc.tid = tid
        vc.mycid = mycid
        
        nav.pushViewController(vc, animated: true)
    }
    
    //
    // MARK: Setup
    //
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fullCardView = FullCardView.loadFromNib()
        fullCardView!.frame = view.frame // TODO why did I have to do this?  Shouldnt autolayout work?
        view.addSubview( fullCardView! )
        
        // right buttons
        let moreImage = UIImage(named: "More Vertical")
        let moreButton = UIBarButtonItem(image: moreImage, style: UIBarButtonItemStyle.plain, target: self, action:#selector(moreButtonAction) )
        
        let chatImage = UIImage(named: "Chat")
        chatButton = UIBarButtonItem(image: chatImage, style: UIBarButtonItemStyle.plain, target: self, action:#selector(chatButtonAction) )
        chatButton.isEnabled = shouldShowChatButton()
        navigationItem.rightBarButtonItems = [ moreButton, chatButton! ]
        
        self.title = "Card Detail".localized
        
        // TODO if this is my card, add an edit button
        //CardHelper.getMyCardIds()
        
        self.edgesForExtendedLayout = UIRectEdge()
        view.backgroundColor = UIConstants.LightGrayBackground
        
        fullCardView!.setCard(card!, tid: tid)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .cardDetail, vc:self )
    }
    
    func leftButtonAction( _ sender: UIBarButtonItem ) {
        unwind()
    }
    
    fileprivate func shouldShowChatButton() -> Bool {
        return card.cid != mycid
    }
    
    fileprivate func unwind() {
        _ = navigationController?.popViewController(animated: true)
    }
    
    func chatButtonAction( _ sender: UIBarButtonItem ) {
        if let tid = tid, let card = card, let cid = card.cid, let nickname = card.nickname {
            
            // do we already have a chat between just these two?
            if let thread = ThreadHelper.findExistingThread(threads: ThreadHistoryModel.instance.threads, cid1: mycid!, cid2: cid) {
                NotificationHelper.signalShowChat(thread.tid!)
                return
            }
            
            chatButton.isEnabled = false
            let progress = ProgressIndicator(parent: view, message: "Creating Side Chat (Progress)".localized)
            
            let newChat = NewChat()
            newChat.mycid = mycid
            newChat.subject = String(format:"Side chat w/%@".localized, nickname )
            newChat.contacts = [ ChatContact(cid:cid,tid:tid) ]
            
            ThreadHelper.createChatWithContacts( newChat ) {
                thread in
                
                progress.stop()
                
                if let thread = thread, let tid = thread.tid {
                    self.unwind()
                    UIHelper.delay(0.5) {
                        NotificationHelper.signalShowChat(tid)
                    }
                } else {
                    self.chatButton.isEnabled = true
                }
            }
        }
    }
    
    func moreButtonAction( _ sender: UIBarButtonItem ) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        if mycid != nil && tid != nil {
            let removeAction = UIAlertAction(title: "Remove from chat".localized, style: .destructive, handler: {
                action in
                
                self.confirmRemove( sender )
            })
            alert.addAction(removeAction)
        }
        
        let flagAction = UIAlertAction(title: "Flag as inappropriate".localized, style: .default, handler: {
            action in
            
            let nav = self.navigationController!
            let cid = self.card!.cid!
            ContentFlaggerViewController.showContentFlagger(nav, type: .Card, id: cid )
        })
        alert.addAction(flagAction)
        
        UIHelper.ipadFixup( alert, barButtonItem:sender )
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func confirmRemove( _ sender: UIBarButtonItem ) {
        let alert = UIAlertController(title: "Confirm removal".localized, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            self.removeFromThread()
        }))
        UIHelper.ipadFixup( alert, barButtonItem:sender )
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func removeFromThread() {
        let progress = ProgressIndicator(parent:self.view, message:"Removing Card".localized)
        MobidoRestClient.instance.removeCardFromThread( card!.cid!, tid:tid!, mycid:mycid! ) {
            result in
            
            if result.failure == nil {
                ChatDatabase.instance.removeCardFromThread(self.card!.cid!,tid:self.tid!)
            }
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                if let failure = result.failure {
                    ProblemHelper.showProblem(self, title: "Problem removing card".localized, failure: failure)
                } else {
                    AnalyticsHelper.trackResult(.cardRemoved)
                }
            })
        }
    }
}
