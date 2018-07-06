import Foundation
import ObjectMapper

class PushNotificationHandler: NSObject {
    
    static let instance = PushNotificationHandler()
    
    // [from: 458461915727, body: Ho, messageType: chat, subject: ride!, created: 2016-02-01T18:23:17.764Z,
    // collapse_key: do_not_collapse, fromCid: n-mike, tid: o-mike, allCids: n-mike]
    func onDidReceiveRemoteNotification( _ userInfo: [AnyHashable: Any], fetchCompletionHandler handler: ((UIBackgroundFetchResult) -> Void)? ) {
        
        if DebugLogger.instance.logging {
            let state = UIApplication.shared.applicationState
            let json = StringHelper.toString( userInfo ) 
            DebugLogger.instance.append( "Remote notification \(state), \(json)" )
        }
        
        // what kind of message is this?
        let messageType = userInfo["messageType"] as? String
        
        if messageType != "meta" && messageType != "chat" {
            DebugLogger.instance.append( "Unknown remote notification: \(userInfo)" )
            if let handler = handler {
                handler(UIBackgroundFetchResult.noData)
            }
            return
        }
        
        if messageType == "chat" {
            handleChatMessage( userInfo )
        }
        
        let msg = parseMessage( userInfo )
        handleMetaMessage( userInfo, msg: msg, fetchCompletionHandler: handler )
        
        // TODO should this happen before the fetchCompletionHandler is done?
        NotificationHelper.signalMessageReceived(msg)
    }
    
    fileprivate func handleChatMessage( _ userInfo: [AnyHashable: Any] ){
        let msg = parseMessage( userInfo )
        let subject = userInfo["subject"] as? String
        let cids = userInfo["cids"] as? String
        
        do {
            if try ChatDatabase.instance.addMessage(msg, subject:subject, cids:cids ) {
                // it appears cards/cids were removed, which is usually just messages arriving out of order
                // Sooo... check with server after a very small delay
                UIHelper.delay( 0.5 ) {
                    do {
                        try SyncHelper.syncThreadHead( msg.tid! )
                    } catch {
                        DebugLogger.instance.append( function: "handleChatMessage():delay", error:error)
                    }
                }
            }
        } catch {
            DebugLogger.instance.append( function: "handleChatMessage():addMessage", error:error)
        }
    }
    
    // handles the .NoData or data consumed callback
    fileprivate func handleMetaMessage( _ userInfo: [AnyHashable: Any], msg:ChatMessage, fetchCompletionHandler handler: ((UIBackgroundFetchResult) -> Void)? ) {
        // is there a sound we should download and cache in ~/Library/Sounds?
        if let meta = msg.meta, let url = meta["com_mobido_background_audio_url"] as? String {
            let soundUrl = URL(string: url)!
            CustomAlertHelper.ensureCustomAlertSound( soundUrl ) {
                usedNetwork, soundpath in
                
                // TODO, it's OK for the first time we receive an alert, for it to play the default notification beep
                // The downside is that its a bad first experience
                // The upside is that the mute switch is honored
                self.playNotificationSound( userInfo: userInfo, soundpath:soundpath )
                handler?(usedNetwork ? .newData : .noData)
            }
            return
        }
        
        handler?(UIBackgroundFetchResult.noData)
    }
    
    // was this a push notification that arrived while the app was open/active, and we need to play the sound?
    func playNotificationSound( userInfo:[AnyHashable: Any], soundpath:String? ) {
        
        if soundpath == nil {
            return
        }

        /* only play the sound if the application was active when it arrived
        if UIApplication.shared.applicationState != .active {
            return
        }*/
        
        if let aps = userInfo["aps"] as? [AnyHashable : Any ] {
            if let _ = aps["sound"] as? String {
                CustomAlertHelper.playSound( soundpath! )
            }
        }
    }
    
    // if this is a chat message, and if there's a tid, return it
    func getMessageTid( _ userInfo: [AnyHashable: Any] ) -> String? {
        return userInfo["tid"] as? String
    }
    
    fileprivate func parseMessage( _ userInfo: [AnyHashable: Any] ) -> ChatMessage {
        let msg = ChatMessage()
        msg.from = userInfo["fromCid"] as? String
        msg.created = userInfo["created"] as? String
        msg.tid = userInfo["tid"] as? String
        msg.body = userInfo["body"] as? String
        
        if let json = userInfo["meta"] as? String {
            if let meta = parseJSONString(json) {
                msg.meta = meta as? [String:AnyObject]
            }
        }
        
        if let json = userInfo["media"] as? String {
            msg.media = Mapper<Media>().mapArray( JSONString:json )
        }
        
        return msg
    }
    
    // Convert a JSON String into an Object using NSJSONSerialization
    func parseJSONString(_ JSON: String) -> Any? {
        let data = JSON.data(using: String.Encoding.utf8, allowLossyConversion: true)
        if let data = data {
            let parsedJSON: Any?
            do {
                parsedJSON = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
            } catch let error {
                print(error)
                parsedJSON = nil
            }
            return parsedJSON
        }
        
        return nil
    }
}
