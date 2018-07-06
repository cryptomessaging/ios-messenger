import Foundation

protocol StatusCallback {
    func onStatus(_ message:String) // Might not be on UI thread!!!
}

class SyncHelper {
    
    static let DEBUG = false
    
    class func syncAsync( _ statusCallback:StatusCallback?, completion:((_ success:Bool)->Void)? ) {
        UIHelper.onMainThread {
            statusCallback?.onStatus("Clearing caches".localized)
            clearCaches(exceptAuth:true, exceptLoginId:true, exceptImages:true ) {
                ThreadHistoryModel.instance.loadWithProblemReporting(.server, statusCallback: statusCallback) {
                    success in
                    
                    if !success {
                        completion?(false)
                    } else {
                        MyCardsModel.instance.loadWithProblemReporting(.server, statusCallback:statusCallback, completion:completion)
                    }
                }
            }
        }
    }
    
    class func clearCaches( exceptAuth:Bool, exceptLoginId:Bool, exceptImages:Bool, completion:@escaping () -> Void ) {
        let start = Date()
        
        GeneralCache.instance.clear()
        LruCache.instance.clear(exceptImages:exceptImages) {
            MyUserDefaults.instance.clear(exceptAuth:exceptAuth, exceptLoginId:exceptLoginId)
            ChatDatabase.instance.clear()
            MyCardsModel.instance.clear()
            
            CoachCardsModel.instance.clear()
            PopularBotCardsModel.instance.clear()
            RecommendedBotCardsModel.instance.clear()
            ThreadHistoryModel.instance.clear()
            
            if SyncHelper.DEBUG {
                let duration = Int( Date().timeIntervalSince(start) * 1000 )
                print( "Finished clearing in \(duration)ms" )
            }
            
            completion()
        }
    }
    
    //
    // Sync chat messages
    //
    
    enum SyncMessagesResult {
        case newMessages
        case noNewMessages
        case chatDeleted
        case error
    }
    
    class func syncChatMessages( _ tid:String, completion: ((SyncMessagesResult)->Void)? ) {
        let db = ChatDatabase.instance
        guard let cachedChat = db.getThread(tid) else {
            print( "STRANGE: no chat row for \(tid)" )
            completion?(.error)
            return
        }
        
        // if a sync has already been done, only get messages newer than chat.lastInSync
        if cachedChat.lastInSync != nil {
            fetchNewerMessages(cachedChat, completion:completion )
            return
        }
        
        // no sync times at all, so make sure to set them
        // fetch as many messages as we can get, newest first and going backwards in time
        let now = TimeHelper.nowAs8601()
        MobidoRestClient.instance.fetchChatMessages(tid) {
            result in
            
            if let failure = result.failure {
                if failure.statusCode == 410 || failure.statusCode == 403 {
                    completion?(.chatDeleted)
                } else {
                    ProblemHelper.showProblem(nil,title:"Failed to sync messages".localized, failure:failure ) {
                        completion?(.error)
                    }
                }
                
                return
            }
            
            let freshChat = result.thread!
            guard let messages = result.messages else {
                // wha?! OK, interpret as no messages in chat at all
                setSyncTimes(freshChat, lastTime:now)
                completion?(.noNewMessages)
                return
            }
            
            if messages.count == 0 {
                setSyncTimes(freshChat, lastTime:now)
                completion?(.noNewMessages)
                return
            }
            
            // let's assume there are no extra messages in db to clean out, and we can only be missing some/all
            do {
                let newMessages = try db.addMessagesOnly(tid, messages: messages, status: MessageStatusName.SUCCESS ) > 0
                if messages.count < result.limit! {
                    setSyncTimes(freshChat, lastTime:now)
                    completion?( signalNewMessages(tid, newMessages:newMessages) )
                } else {
                    // more to fetch...
                    let earliestMessageTime = findEarliestMessageTime(messages)
                    try fetchOlderMessages( freshChat, beforeTime:earliestMessageTime, newMessages:newMessages, now:now, completion:completion )
                }
            } catch {
                completion?(.error)
            }
        }
    }
    
    class func setSyncTimes(_ chat:ChatThread, lastTime:String) {
        if let created = chat.created {
            do {
                try ChatDatabase.instance.updateSyncTimes( chat.tid!, firstTime:created, lastTime:lastTime )
            } catch {
                DebugLogger.instance.append( function: "setSyncTimes()", error: error )
            }
        } else {
            print( "STRANGE: chat missing created \(String(describing: chat.tid))")
        }
    }
    
    class func signalNewMessages(_ tid:String,newMessages:Bool) -> SyncMessagesResult {
        if newMessages {
            NotificationHelper.signalChatMessageDbChanged(tid)
            return .newMessages
        } else {
            return .noNewMessages
        }
    }
    
    //
    // Fetch messages newer than last sync
    //
    
    // get most recent messages, ones between chat.lastInSync and now()
    class func fetchNewerMessages(_ chat:CachedThread, completion: ((SyncMessagesResult)->Void)? ) {
        let tid = chat.tid!
        let now = TimeHelper.nowAs8601()
        MobidoRestClient.instance.fetchChatMessages(tid, afterTime:chat.lastInSync!) {
            result in
            
            if let failure = result.failure {
                if failure.statusCode == 410 {
                    completion?(.chatDeleted)
                } else {
                    ProblemHelper.showProblem(nil,title:"Failed to sync messages".localized, failure:failure ) {
                        completion?(.error)
                    }
                }
                
                return
            }
            
            let db = ChatDatabase.instance
            do {
                guard let messages = result.messages else {
                    // wha?! Assume no new messages...
                    try db.updateLastSyncTime( tid, lastTime:now )
                    completion?(.noNewMessages)
                    return
                }
                
                // let's assume there are no extra (i.e. deleted) messages in db, and we can only be missing them
                let newMessages = try db.addMessagesOnly(tid, messages: messages, status: MessageStatusName.SUCCESS ) > 0
                
                // did we get all the new messages (happens 99% of the time)
                if( messages.count < result.limit! ) {
                    try db.updateLastSyncTime( tid, lastTime:now )
                    completion?( signalNewMessages(tid, newMessages:newMessages) )
                    return
                }
                
                // still more messages to get
                let earliestTime = findEarliestMessageTime( messages )
                let updateSyncTime:()->Void = {
                    do {
                        try db.updateLastSyncTime( tid, lastTime:now )
                    } catch {
                        DebugLogger.instance.append( function:"fetchNewerMessages():updateLastSyncTime{}", error:error )
                    }
                }
                fetchMoreMessages( result.thread!, startTime:chat.lastInSync!, endTime:earliestTime, updateSyncTime:updateSyncTime, newMessages:newMessages, completion: completion )
            } catch {
                DebugLogger.instance.append( function:"fetchNewerMessages()", error:error )
            }
        }
    }

    class func fetchMoreMessages(_ chat:ChatThread, startTime:String, endTime:String, updateSyncTime:@escaping ()->Void, newMessages:Bool, completion: ((SyncMessagesResult)->Void)? ) {
        let tid = chat.tid!
        MobidoRestClient.instance.fetchChatMessages(tid, startTime:startTime, endTime:endTime ) {
            result in
            
            if ProblemHelper.showProblem(nil,title:"Failed to sync messages".localized, failure:result.failure ) {
                completion?(.error)
                return
            }
            
            let db = ChatDatabase.instance
            guard let messages = result.messages else {
                // wha?! Assume no more messages coming...
                //updateSyncTime( chat, lastSyncTime:lastSyncTime )
                updateSyncTime()
                completion?( signalNewMessages(tid, newMessages:newMessages) )
                return
            }
            
            // let's assume there are no extra (i.e. deleted) messages in db, and we can only be missing them
            // NOTE: handles empty arrays
            let addMessageCount:Int!
            do {
                addMessageCount = try db.addMessagesOnly(tid, messages: messages, status: MessageStatusName.SUCCESS )
            } catch {
                DebugLogger.instance.append( function:"fetchMoreMessages()", error:error)
                completion?(.error)
                return
            }
            let newMessages = newMessages || addMessageCount > 0
            
            // did we get all the new messages (happens 99% of the time)
            if( messages.count < result.limit! ) {
                //updateSyncTime( chat, lastSyncTime:lastSyncTime )
                updateSyncTime()
                completion?( signalNewMessages(tid, newMessages:newMessages) )
                return
            }
            
            // still more messages to get? recurse...
            let earliestTime = findEarliestMessageTime( messages )
            fetchMoreMessages( chat, startTime:startTime, endTime:earliestTime, updateSyncTime:updateSyncTime, newMessages:newMessages, completion:completion )
        }
    }
    
    //
    // Fetch messages earlier/older than time
    //
    
    // get older messages, ones between chat.created and beforeTime
    class func fetchOlderMessages( _ chat:ChatThread, beforeTime:String, newMessages:Bool, now:String, completion: ((SyncMessagesResult)->Void)? ) throws {
        let tid = chat.tid!
        MobidoRestClient.instance.fetchChatMessages(tid, beforeTime:beforeTime ) {
            result in
            
            if ProblemHelper.showProblem(nil,title:"Failed to sync messages".localized, failure:result.failure ) {
                completion?(.error)
                return
            }
            
            do {
                let db = ChatDatabase.instance
                guard let messages = result.messages else {
                    // wha?! Assume no new messages...
                    try db.updateFirstSyncTime( tid, firstTime:chat.created! )
                    completion?( signalNewMessages(tid, newMessages:newMessages) )
                    return
                }
                
                // let's assume there are no extra (i.e. deleted) messages in db, and we can only be missing them
                let addMessageCount = try db.addMessagesOnly(tid, messages: messages, status: MessageStatusName.SUCCESS )
                let newMessages = addMessageCount > 0 || newMessages
                
                // did we get all the new messages (happens 99% of the time)
                if( messages.count < result.limit! ) {
                    try db.updateFirstSyncTime( tid, firstTime:chat.created! )
                    completion?( signalNewMessages(tid, newMessages:newMessages) )
                    return
                }
                
                // still more messages to get
                let earliestTime = findEarliestMessageTime( messages )
                let updateSyncTime:()->Void = {
                    do {
                        try db.updateSyncTimes( tid, firstTime:chat.created!, lastTime:now )
                    } catch {
                        DebugLogger.instance.append( function:"fetchOlderMessages():updateSyncTime{}", error:error )
                    }
                }
                fetchMoreMessages( chat, startTime:chat.created!, endTime:earliestTime, updateSyncTime:updateSyncTime, newMessages:newMessages, completion: completion )
            } catch {
                DebugLogger.instance.append( function:"fetchOlderMessages()", error:error )
            }
        }
    }
    
    class func findEarliestMessageTime(_ messages:[ChatMessage]) -> String {
        var earliest:String!
        
        for m in messages {
            if let created = m.created {
                if earliest == nil {
                    earliest = created
                } else if TimeHelper.isAscending(created, t2: earliest) {
                    earliest = created
                }
            }
        }
        
        return earliest
    }
    
    class func syncThreadHead( _ tid:String ) throws {
        MobidoRestClient.instance.fetchChatHead(tid) {
            result in
            
            // 410s/GONE are OK.  We get these when receiving a "been deleted" message as the thread is being deleted
            if let failure = result.failure {
                if failure.statusCode != 410 {
                    ProblemHelper.showProblem(nil,title:"Failed to sync chat cards".localized, failure:failure )
                }
                return
            }
            
            if let thread = result.thread {
                do {
                    try ChatDatabase.instance.updateThread(thread)
                } catch {
                    DebugLogger.instance.append(function: "syncThreadHead()", error:error )
                }
            }
        }
    }
}
