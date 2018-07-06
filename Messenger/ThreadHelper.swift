import Foundation

class ThreadHelper {
    
    static let DEBUG = false
    
    class func findExistingThread( threads:[CachedThread], cid1:String, cid2:String ) -> CachedThread? {
        // do we already have a chat going between these two cids?
        for t in threads {
            if let cids = StringHelper.asArray(t.cids) { // convert csv to array of strings
                if cids.count == 2 {
                    if cids.index(of:cid1) != nil && cids.index(of:cid2) != nil {
                        return t
                    }
                }
            }
        }
        
        // failed to find the chat
        return nil
    }
    
    class func createChatWithContacts(_ chat:NewChat, completion:@escaping (ChatThread?)->Void ) {
        MobidoRestClient.instance.createChat(chat) {
            result in
            
            // any problems?
            if ProblemHelper.showProblem(nil, title: "Failed to create side chat".localized, failure: result.failure ) {
                completion(nil)
            }
            
            if let newthread = result.thread {
                AnalyticsHelper.trackResult(.chatCreated)
                ChatDatabase.instance.addThread(newthread) // add to local database so we can immediately pop up chat
                completion(newthread)
            } else {
                completion(nil) // wha?!
            }
        }
    }
 
    class func createPublicChat( hostcid:String, allcids:[String], subject:String?, completion:@escaping (Failure?, ChatThread?)->Void ) {
        
        // make sure values from form are in card object
        let thread = NewPublicChat()
        thread.cid = hostcid
        thread.allcids = allcids
        thread.subject = subject ?? "New Chat (Subject)".localized  // TODO better alt name
        
        MobidoRestClient.instance.createPublicChat(thread) {
            result in
            
            /*if ProblemHelper.showProblem(nil, title:"Problem creating chat".localized, failure:result.failure ) {
                completion(nil)
                return
            }*/
            
            if let newthread = result.thread {
                AnalyticsHelper.trackResult(.chatCreated)
                ChatDatabase.instance.addThread(newthread)
                completion( nil, newthread )
                return
            }
            
            // assume failure is filled in...
            completion(result.failure,nil)
        }
    }
    
    //
    // MARK: Utility
    //
    
    class func onStatus(_ callback:StatusCallback?, status:String ) {
        if let cb = callback {
            cb.onStatus(status)
        }
    }
    
    class func areCidsRemoved( _ oldCids:String?, newCids:String? ) -> Bool {
        if( DEBUG ) {
            print( "Comparing old \(String(describing: oldCids)) to new \(String(describing: newCids))")
        }
        
        if newCids == nil || oldCids == nil {
            return false
        }
        
        let new = StringHelper.asArray(newCids)!
        if let old = StringHelper.asArray(oldCids) {
            for cid in old {
                if new.contains(cid) != true {
                    // the new list is missing a card from the old one - a card has been removed
                    return true
                }
            }
        }
        
        return false
    }
}
