import Foundation

// Register all the notification names here to assure no namespace conflicts!
enum NotificationName:String {
    case chatMessageDbChanged
    case chatMessageReceived
    case noCards    // I have no cards! :(
    case showChat
    case blindApn
    case cardsDeleted
    case threadModelChanged
    case threadDbChanged
    case myCardsModelChanged
    case locationUpdate
    case locationFailure
}

protocol LocalNotificationAware {
    func onLocalNotification()
}

class NotificationHelper {
    
    static let DEBUG = false
    
    class func addObserver(_ observer: AnyObject, selector:Selector, name: NotificationName ) {
        NotificationCenter.default.addObserver(observer, selector: selector, name:NSNotification.Name(rawValue:name.rawValue), object:nil )
    }
    
    class func removeObserver(_ observer:AnyObject) {
        NotificationCenter.default.removeObserver(observer)
    }
    
    //
    // MARK: Notifications
    //
    
    class func signalShowChat( _ tid:String ) {
        signal( .showChat, info:tidInfo(tid) )
    }
    
    // messages in one (or many) chats updated
    class func signalChatMessageDbChanged( _ tid:String? ) {
        signal( .chatMessageDbChanged, info:tidInfo(tid) )
    }
    
    // some/all summary thread info updated
    class func signalThreadDbChanged( _ tid:String? ) {
        signal( .threadDbChanged, info:tidInfo(tid) )
    }
    
    class func signalThreadModelChanged( _ tid:String? ) {
        signal( .threadModelChanged, info:tidInfo(tid) )
    }
    
    class func signalMessageReceived( _ msg:ChatMessage ) {
        var info = [String:AnyObject]()
        info["tid"] = msg.tid as AnyObject?
        info["msg"] = msg
        
        DispatchQueue.main.async {
            let name = NSNotification.Name(rawValue: NotificationName.chatMessageReceived.rawValue )
            NotificationCenter.default.post(name:name, object:nil, userInfo:info )
        }
    }
    
    fileprivate class func tidInfo( _ tid:String? ) -> Dictionary<String,String>? {
        if let tid = tid {
            return ["tid":tid]
        } else {
            return nil
        }
    }

    class func signalNoCards() {
        signal( .noCards, info: nil )
    }
    
    //
    // MARK: Utility
    //
    
    class func signal( _ name:NotificationName ) {
        signal(name, info:nil)
    }
    
    class func signal( _ name:NotificationName, info:Dictionary<String,String>? ) {
        if NotificationHelper.DEBUG { print( "signal() \(name)" ) }
        DispatchQueue.main.async {
            let name = NSNotification.Name(rawValue: name.rawValue )
            NotificationCenter.default.post(name:name, object:nil, userInfo:info )
        }
    }
}
