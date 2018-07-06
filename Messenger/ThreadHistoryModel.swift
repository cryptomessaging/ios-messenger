//
//  ThreadHistoryModel.swift
//  Messenger
//
//  One layer above the disk cache - the in-memory model that's shared between view controllers.
//  Can be used as a DataSource for TableViews.
//
//  load(.any) uses any locally cached values, this should be called before using any values
//  load(.server) makes sure the cached values came from the server
//
//  When data is ready, both the completion handler is called AND a NotificationCenter event is fired
//
//  TODO: handle concurrent requests
//
//  Created by Mike Prince on 3/19/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class ThreadHistoryModel : NSObject {
    static let instance = ThreadHistoryModel()
    static let DEBUG = false
    
    var threads = [CachedThread]()
    
    enum State {
        case dirty  // memory is out of sync with local cache, or local cache is out of sync with server?
        case localLoaded
        case serverLoaded
    }
    
    private(set) var state:State = .dirty
    
    fileprivate override init() {
        super.init()
        if ThreadHistoryModel.DEBUG { print("ThreadHistoryModel.init()") }
        NotificationHelper.addObserver(self, selector: #selector(onThreadDbChanged), name: .threadDbChanged )
    }
    
    deinit {
        if ThreadHistoryModel.DEBUG { print("ThreadHistoryModel.deinit()") }
        NotificationHelper.removeObserver(self)
    }
    
    func clear() {
        if ThreadHistoryModel.DEBUG { print("ThreadHistoryModel.clear()") }
        threads.removeAll()
        state = .dirty
    }
    
    func onThreadDbChanged() {
        loadLocal() {}
    }
    
    func loadWithProblemReporting( _ source:DataSource, statusCallback:StatusCallback?, completion:((_ success:Bool) -> Void )? ) {
        if ThreadHistoryModel.DEBUG { print("THM.loadWithProblemReporting()") }
        load( source, statusCallback:statusCallback ) {
            failure in
            
            if ProblemHelper.showProblem(nil,title:"Failed to fetch chat history (Title)".localized,failure:failure) {
                completion?(false)
            } else {
                completion?(true)
            }
        }
    }
    
    func load( _ source:DataSource, statusCallback:StatusCallback?, completion:((_ failure:Failure?) -> Void)? ) {
        if ThreadHistoryModel.DEBUG { print("THM.load()") }
        let nextFullThreadSync = MyUserDefaults.instance.getNextFullThreadSync()
        if source == .server || nextFullThreadSync == 0 {
            // go straight to server, don't consider local cache
            fetch( statusCallback, completion:completion )
            return
        }
        
        // implied source == .local
        
        // is it time to resync in background?
        let now = CFAbsoluteTimeGetCurrent()
        if nextFullThreadSync <= now {
            if ThreadHistoryModel.DEBUG {
                print( "Needed to sync \(nextFullThreadSync) <= \(now)")
            }
            
            // schedule next sync a few minutes from now in case this one fails
            MyUserDefaults.instance.setNextFullThreadSync( now + 300 )   // five minutes in seconds
            
            fetch( nil ) { // server fetch done in background, fall through to local DB get() in mean time
                failure in
                
                if failure != nil {
                    // report problem?
                    ProblemHelper.showProblem(nil,title:"Failed to fetch chat history (Title)".localized,failure:failure!) {
                        // force next sync ASAP
                        self.state = .dirty
                        MyUserDefaults.instance.setNextFullThreadSync( 0 )
                    }
                }
            }
        }
        
        // is the local cache ok for now (i.e. not dirty)
        if state != .dirty {
            if ThreadHistoryModel.DEBUG { print("THM.load() -> using cache") }
            completion?(nil)
            return
        }
        
        // OK to use local database/cache
        loadLocal() {
            completion?(nil)
        }
    }
    
    fileprivate func loadLocal(completion:@escaping ()->Void) {
        if ThreadHistoryModel.DEBUG { print("THM.loadLocal()") }
        let db = ChatDatabase.instance
        let threads = db.getThreads()
        UIHelper.onMainThread {
            self.threads = threads
            if self.state == .dirty {
                // don't downgrade from .serverLoaded just because we fetched locally
                self.state = .localLoaded
            }
            NotificationHelper.signal(.threadModelChanged)
            completion()
        }
    }
    
    // fetch threads from server and update local caches
    fileprivate func fetch( _ statusCallback:StatusCallback?, completion:((_ failure:Failure?) -> Void)? ) {
        if ThreadHistoryModel.DEBUG { print("THM.fetch()") }
        // pull ground truth from server
        statusCallback?.onStatus( "Fetching history".localized )
        MobidoRestClient.instance.fetchChatHistory {
            result in
            
            if let failure = result.failure {
                completion?(failure)
                return
            }
            
            // convert rest events to sqlite events
            var threadMap = [String:CachedThread]()
            if let map = result.threads {
                for( key, thread ) in map {
                    let cids = StringHelper.toCsv(thread.cids)
                    let msg = thread.msg
                    let updated = msg == nil ? nil : msg!.created
                    let entry = CachedThread(tid:key,cids:cids,subject:thread.subject,updated:updated,msg:msg)
                    threadMap[key] = entry
                }
            }
            
            // cache in DB for later
            statusCallback?.onStatus( "Caching history".localized )
            ChatDatabase.instance.syncThreads( threadMap );
            MyUserDefaults.instance.setNextFullThreadSync( CFAbsoluteTimeGetCurrent() + Double(Seconds.IN_ONE_HOUR) )
            if ThreadHistoryModel.DEBUG { print( "Threads synced" ) }
            
            // NOTE: syncing with DB will trigger another (second) reload of this memory model,... TODO better?
            
            // sort, newest first
            let unsorted = Array( threadMap.values )
            let sorted = unsorted.sorted {
                let r = $0.msg!.created!.localizedCompare($1.msg!.created!)
                return r == ComparisonResult.orderedDescending
            }
            
            // and finally, save the results in memory but only using the main thread to avoid race conditions
            UIHelper.onMainThread {
                self.threads = sorted
                self.state = .serverLoaded
                //NotificationHelper.signal(.threadModelChanged)  Because .threadDbChanged is trigger by sync above, loadLocal() gets called which does this signal
                completion?(nil)
            }
        }
    }
}
