import Foundation
import Chatto

protocol ChatDataSourceUpdateListener: class {
    func onChatDataSourceUpdate( _ source: ChatDataSource )
}

class ChatDataSource: NSObject, ChatDataSourceProtocol {
    
    fileprivate var thread:CachedThread?
    fileprivate var mycid:String?   // so we know which message bubbles orient to right
    
    //=== ChatDataSourceProtocol ===
    
    var hasMoreNext = false
    var hasMorePrevious = false
    var chatItems = [ChatItemProtocol]()
    weak var delegate:ChatDataSourceDelegateProtocol?
    
    // We can't use the ChatDataSourceDelegateProtocol outside of its module, so we have to create another... sigh
    weak var updateListener:ChatDataSourceUpdateListener?
    
    func reset(_ thread:CachedThread, mycid:String?) {
        self.thread = thread
        self.mycid = mycid  // might still be nil!!!
        
        reload()
    }
    
    func getTid() -> String? {
        if let t = thread {
            return t.tid
        } else {
            return nil
        }
    }
    
    override init() {
        super.init()
        
        // the APN has already been processed and pushed in to the database
        NotificationHelper.addObserver(self, selector:#selector(messageDatabaseChanged), name:.chatMessageDbChanged)
        
        // the APN has been processed and pushed into the database and we are about to be shown
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object:nil)
        
        // the APN resulted in a notification, but the user tapped the app icon instead AND iOS doesn't tell us what the notification was :(
        NotificationHelper.addObserver(self, selector:#selector(blindApn), name:.blindApn)
    }
    
    deinit {
        NotificationHelper.removeObserver(self) // also removes UIApplicationWillEnterForegroundNotification
    }
    
    func willEnterForeground() {
        reload()
    }
    
    func messageDatabaseChanged(_ notification:Notification) {
        if let info = notification.userInfo {
            if let tid = info["tid"] as? String {
                if tid == getTid() {
                    reload()
                }
                return; // if not our tid then DONT reload
            }
        }
        
        // if there's no tid, reload to be safe
        reload()
    }
    
    // the APN resulted in a notification, but the user tapped the app icon instead AND iOS doesn't
    // tell us what the notification was :(
    func blindApn() {
        if let tid = getTid() {
            SyncHelper.syncChatMessages(tid, completion:nil )
        }
    }
    
    func loadNext() {} // Should trigger chatDataSourceDidUpdate with UpdateType.Pagination
    func loadPrevious() {}  // Should trigger chatDataSourceDidUpdate with UpdateType.Pagination
    
    func adjustNumberOfMessages(preferredMaxCount: Int?, focusPosition: Double, completion:(_ didAdjust: Bool) -> Void) {
        // If you want, implement message count contention for performance, otherwise just call completion(false)
        completion(false)
    }
    
    //
    // MARK: Load messages from database
    //
    
    func reload() {
        if thread == nil {
            return
        }
        let tid = thread!.tid!
        
        var update = [ChatItemProtocol]()
        var latestMessageTime:String?
        
        var lastMessageCid:String?
        ChatDatabase.instance.getThreadMessages(tid) {
            rowid,cid,body,created,media,status in
            
            let st = status == nil ? "success" : status!
            let isMine = cid == self.mycid  // mycid might be nil!
            let sameSender = cid == lastMessageCid
            
            if let media = media {
                let msg = MessageHelper.createPhotoMessage( rowid, tid:tid, cid:cid, isMine:isMine, sameSenderAsLastMessage:sameSender, created:created, media:media, status:st )
                update.append( msg )
            } else if let body = body {
                let msg = MessageHelper.createTextMessage( rowid, tid:tid, cid:cid, isMine:isMine, sameSenderAsLastMessage:sameSender, created:created, text:body, status:st )
                update.append( msg )
            } else {
                print( "Unhandled message during reload" )
            }
            
            if TimeHelper.isAscending(latestMessageTime,t2: created) {
                latestMessageTime = created
            }
            
            lastMessageCid = cid
        }
        
        // only do in main thread
        DispatchQueue.main.async(execute: {
            self.chatItems = update
            self.delegate?.chatDataSourceDidUpdate(self)
            self.updateListener?.onChatDataSourceUpdate(self)
        })
    }
}
