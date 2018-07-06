import Foundation
import SQLite
import ObjectMapper
import Chatto

//========== Our tables ==========

class MessageTableManager: TableManager {
    func create(_ db:SqliteDatabase) throws {
        db.runSql(
            "CREATE TABLE messages(" +
            "\"from\" TEXT, body TEXT, tid TEXT, created TEXT, status TEXT, media TEXT," +
            "PRIMARY KEY(tid,created,\"from\"))"
        )
    }
    
    func revision(_ db:SqliteDatabase,fromVersion:Int, toVersion:Int) throws {
        if fromVersion == 5 && toVersion == 6 {

            db.runSql( "ALTER TABLE messages ADD COLUMN media TEXT")
            return
        }
        
        db.runSql("DROP TABLE IF EXISTS messages")
        try create(db)
    }
    
    func clear(_ db:SqliteDatabase) throws {
        db.runSql( "DELETE FROM messages")
    }
}

class ChatTableManager: TableManager {
    func create(_ db:SqliteDatabase) throws {
        db.runSql(
            "CREATE TABLE chats("
                + "tid TEXT, cids TEXT, subject TEXT,"
                + "updated TEXT, lastBody TEXT, lastFrom TEXT,"
                + "firstInSync TEXT, lastInSync TEXT,"   // defines window of synced messages
                + "PRIMARY KEY(tid))"
        )
    }
    
    func revision(_ db:SqliteDatabase,fromVersion:Int, toVersion:Int) throws {
        if fromVersion == 5 && toVersion == 6 {
            // nothing to do
            return
        }
        
        db.runSql("DROP TABLE IF EXISTS chats")
        try create(db)
    }
    
    func clear(_ db:SqliteDatabase) throws {
        db.runSql( "DELETE FROM chats")
    }
}

//============ ChatDatabase =========

class ChatDatabase: SqliteDatabase {
    
    static let instance = ChatDatabase()
    
    fileprivate init() {
        super.init( name:"Chat", version:6 )
    }
    
    override func tableManagers() -> [TableManager] {
        return [ MessageTableManager(), ChatTableManager() ]
    }
    
    //
    // MARK: Public methods
    //
    
    func removeMessages(_ tid:String, timestamps:[String]) {
        let sql = "DELETE FROM messages WHERE tid=? AND created IN("
        let fixedParams:[Binding?] = [tid]
        var inParams:[Binding?] = [Binding?]()
        for ts in timestamps {
            inParams.append( ts )
        }
        
        deleteRows( sql, fixedParams: fixedParams, inParams: inParams )
        
        NotificationHelper.signalChatMessageDbChanged(tid)
    }
    
    // Updates message AND thread
    func addMessage( _ message:ChatMessage, status:String? ) throws  {
        try updateThread(message, subject:nil, cidArray:nil );

        // not in database yet, so add
        try addMessageOnly(message, status:status );
    }
    
    // For messages coming in from GCM
    // NOTE: sometimes messages adding users come in out of order, so the cids list should be additive,
    // and if any cids appear to be removed we should verify that with the server
    // returns TRUE if cids should have been removed.  Caller should sync thread with server.
    func addMessage( _ message:ChatMessage, subject:String?, cids:String? ) throws  -> (Bool) {
        //let hack = StringHelper.asArray(cids)!.first!
        
        let (revisedCids,isCidsRemoved) = bestCids(message.tid!, newCids:cids )
        try updateThread(message, subject:subject, cids:revisedCids );
        
        // not in database yet, so add
        try addMessageOnly(message, status:"success" );
        
        // were any cids removed?
        return isCidsRemoved
    }
    
    fileprivate func bestCids(_ tid:String, newCids:String? ) -> (revisedCids:String?,isCidsRemoved:Bool) {
        if newCids == nil {
            return (nil,false)
        }
        
        // only fetch current cids if new ones are being provided
        let oldCids = getThreadCids( tid )
        if ThreadHelper.areCidsRemoved(oldCids, newCids:newCids) {
            // add the cids together, and use that list until we confirm with server
            let newArray = StringHelper.asArray(newCids)!
            let oldArray = StringHelper.asArray(oldCids)!
            
            let uniques = Set(newArray) + oldArray
            let revisedArray = [String](uniques)

            return (StringHelper.toCsv(revisedArray),true)
        } else {
            return (newCids,false)
        }
    }
    
    // only updates message and not the thread summary
    func addMessageOnly( _ message:ChatMessage, status:String? ) throws {
        if message.body == nil && message.media == nil {
            // informational/meta only messages should not be saved
            DebugLogger.instance.append( function:"addMessageOnly()", message:"WARNING: Tried to insert message with no body or media: \(String(describing: message.toJSONString()))" )
            return
        }
        
        // clean the base64 data out of media
        var jsonMedia:String?
        if let media = message.media {
            var tmp = [Media]()
            for m in media {
                let retype = m.type == "image/jpeg;base64" ? "image/jpeg" : m.type
                tmp.append( Media(type: retype!, src:nil, meta:m.meta ) )
            }
            
            jsonMedia = tmp.toJSONString()
        }
        
        let sql = "INSERT OR IGNORE INTO messages(\"from\",body,created,tid,status,media) VALUES(?,?,?,?,?,?)"
        let params:[Binding?] = [message.from, message.body, message.created, message.tid, status, jsonMedia ]
        let count = try update(sql, params: params)
        if count > 0 {
            //print( "Added message \(message.toJSONString())")
            NotificationHelper.signalChatMessageDbChanged(message.tid)
        }
    }
    
    // Bulk update, does not check for additional messages in db
    func addMessagesOnly( _ tid:String, messages:[ChatMessage]?, status:String? ) throws -> Int {
        guard let messages = messages else {
            return 0 // nothing to do
        }
        if messages.count == 0 {
            return 0
        }
        
        let start = TimeHelper.getMillis()
        
        var params:[Binding?] = []
        var sql:String?
        
        var count = 0
        var total = 0
        for msg in messages {
            var jsonMedia:String?
            if let media = msg.media {
                jsonMedia = media.toJSONString()
            }
            
            if msg.body != nil || jsonMedia != nil {
                if sql == nil {
                    sql = "INSERT OR IGNORE INTO messages(\"from\",body,created,tid,media,status) VALUES(?,?,?,?,?,?)"
                } else {
                    sql = sql! + ",(?,?,?,?,?,?)"
                }
                
                params = params + [msg.from, msg.body, msg.created, tid, jsonMedia, status ]
                count += 1
                if count > 50 {
                    let updateCount = try update(sql!, params: params)
                    total += updateCount
                    
                    sql = nil
                    params.removeAll()
                    count = 0
                }
            } else {
                print( "WARNING: Tried to insert message with no body or media: \(msg.toJSONString())" )
            }
        }
        
        // handle any left-overs (partial batch)
        if sql != nil {
            let updateCount = try update(sql!, params: params)
            total += updateCount
        }
        
        let duration = TimeHelper.getMillisDurationSince(start)
        if SqliteDatabase.DEBUG { print("Inserted \(total) messages in \(duration)ms") }
        
        /*if total > 0 {
            NotificationHelper.signalMessagesUpdated(tid)
        }*/
        
        return total
    }
    
    // oldCreated was the local time we created the message
    // msg.created should now hold the authoratitive server creation time
    func updateMessage(_ tid:String,from:String,oldCreated:String,newCreated:String,newStatus:String) throws {
        let sql = "UPDATE OR IGNORE messages SET created=?, status=? WHERE tid=? AND created=? AND \"from\"=?"
        let params:[Binding?] = [newCreated, newStatus, tid, oldCreated, from ]
        let count = try update(sql, params: params)
        if count == 0 {
            // we lost a race condition; The new server one arrived before we could update our local one,
            // so delete our errant local message
            let sql = "DELETE FROM messages WHERE tid=? AND \"from\"=? AND created=?"
            let params:[Binding?] = [tid, from, oldCreated ]
            let count = try update( sql, params:params )
            if count != 1 {
                print("Fishy... failed to delete local message")
            }
        }
        //if SqliteDatabase.DEBUG {
        //print( "Message updated \(params).self c:\(count)" )
        //}
        
        NotificationHelper.signalChatMessageDbChanged(tid)
    }
    
    //
    // Chats
    //
    
    // used when adding new thread I created
    func addThread( _ thread:ChatThread ) {
        let now = TimeHelper.nowAs8601()
        let cids = cidArrayToString( thread.cids )
        let sql = "INSERT INTO chats(cids,updated,subject,tid) VALUES(?,?,?,?)"
        let params:[Binding?] = [cids,now,thread.subject,thread.tid]
        runSql( sql, params: params )
        
        NotificationHelper.signalThreadDbChanged(thread.tid)
    }
    
    func removeThread( _ tid:String ) {
        var sql = "DELETE FROM messages WHERE tid=?"
        let params:[Binding?] = [tid]
        runSql( sql, params: params )
        
        sql = "DELETE FROM chats WHERE tid=?"
        runSql( sql, params: params )
        
        NotificationHelper.signalThreadDbChanged(tid)
    }
    
    func removeCardFromThread(_ cid:String, tid:String ) {
        let params:[Binding?] = [tid]
        let stmt = prepare( "SELECT cids FROM chats WHERE tid=?", params:params )
        for row in stmt {
            let csv = asString(row[0])
            if var ids = StringHelper.asArray(csv) {
                if let p = ids.index(of: cid) {
                    ids.remove(at: p)
                    let newCids = StringHelper.toCsv(ids)
                    let params:[Binding?] = [newCids, tid]
                    runSql( "UPDATE chats SET cids=? WHERE tid=?", params:params )
                }
            }
        }
        
        NotificationHelper.signalThreadDbChanged(tid)
    }
    
    func getThreadMessages( _ tid:String?, callback:(_ rowid:String,_ cid:String,_ body:String?,_ created:String,_ media:[Media]?,_ status:String?) -> Void) {
        if tid == nil {
            return
        }
        
        let sql = "SELECT rowid,\"from\",body,created,media,status FROM messages WHERE tid=? ORDER BY created ASC"
        let params:[Binding?] = [tid]
        let stmt = prepare( sql, params:params )
        for row in stmt {
            let rowid = asString(row[0])
            let cid = asString(row[1])
            let body = asString(row[2])
            let created = asString(row[3])
            var media:[Media]?
            if let json = asString(row[4]) {
                media = Mapper<Media>().mapArray( JSONString:json )
            }
            let status = asString(row[5])
            
            callback(rowid!, cid!, body, created!, media, status)
        }
    }
    
    func getThreads() -> [CachedThread] {
        let sql = "SELECT \(ChatDatabase.CHAT_COLUMNS) FROM chats ORDER BY updated DESC LIMIT 100"
        let stmt = prepare( sql )
        var result = [CachedThread]()
        for row in stmt {
            let t = parseThread( row )
            result.append(t)
        }
        
        if SqliteDatabase.DEBUG {
            let json = Mapper().toJSONString(result, prettyPrint:true)
            print( "GetThreads(): \(json)")
        }
        
        return result
    }
    
    func getThread(_ tid:String) -> CachedThread? {
        let params:[Binding?] = [tid]
        let stmt = prepare( "SELECT \(ChatDatabase.CHAT_COLUMNS) FROM chats WHERE tid=?", params:params )
        if let row = stmt.next() {
            return parseThread( row )
        } else {
            return nil
        }
    }
    
    func getThreadCids(_ tid:String) -> String? {
        let params:[Binding?] = [tid]
        let stmt = prepare( "SELECT cids FROM chats WHERE tid=?", params:params )
        if let row = stmt.next() {
            return asString( row[0] )
        } else {
            return nil
        }
    }
    
    static let CHAT_COLUMNS = "tid,cids,subject,updated,lastFrom,lastBody,firstInSync,lastInSync"
    fileprivate func parseThread( _ row:[Binding?] ) -> CachedThread {
        let t = CachedThread()
        t.tid = asString(row[0])
        t.cids = asString(row[1])   // comma separated string
        t.subject = asString(row[2])
        t.updated = asString(row[3])

        let from = asString(row[4])
        let body = asString(row[5])
        if from != nil || body != nil {
            let msg = LatestChatMessage()
            msg.cid = from
            msg.body = body
            msg.created = t.updated
            t.msg = msg
        }
        
        t.firstInSync = asString(row[6])
        t.lastInSync = asString(row[7])
        
        return t
    }
    
    fileprivate func asString(_ binding:Binding?) -> String? {
        if let i = binding as? Int64 {
            return String(i)
        } else if let s = binding as? String {
            return s
        } else if binding == nil {
            return nil
        } else {
            print( "Unknown type \(binding!)")
            return nil
        }
    }
    
    //
    // MARK: Sync threads
    //
    
    func syncThreads( _ threadMap:[String:CachedThread] ) {
        let start = CFAbsoluteTimeGetCurrent() // NSDate().timeIntervalSince1970
        
        var updateRows = [CachedThread]()       // rows to update
        var deleteTids = [Binding?]()           // rows to delete
        var threadMap = threadMap
        
        // read out all the existing threads, compare, and see what we need to change
        let stmt = prepare( "SELECT \(ChatDatabase.CHAT_COLUMNS) FROM chats" )
        for row in stmt {
            let cached = parseThread( row )
            if cached.tid == nil  {
                print( "Thread row is missing tid - Impossible!")
            } else if let update = threadMap[cached.tid!] {
                threadMap.removeValue( forKey: cached.tid! )  // left-overs will be created/inserted
                
                // check to make sure values are all the same
                if update.isEqual(cached) != true {
                    updateRows.append( update )
                }
            } else {
                // cached row does not match what's on server, so delete
                deleteTids.append( cached.tid! )
            }
        }
        
        // process updates
        for thread in updateRows {
            let msg = thread.msg ?? LatestChatMessage()
            updateThread(msg.body,lastFrom:msg.cid,updated: msg.created, cids:thread.cids, subject:thread.subject, tid:thread.tid)
        }
        
        // process inserts
        for thread in threadMap.values {
            let msg = thread.msg ?? LatestChatMessage()
            insertThread(msg.body,lastFrom:msg.cid,updated: msg.created, cids:thread.cids, subject:thread.subject, tid:thread.tid)
        }
        
        // process deletes
        deleteRows( "DELETE FROM chats WHERE tid IN(", keys:deleteTids)
        
        if SqliteDatabase.DEBUG {
            let duration = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            print( "Synced chats with SQLite in \(duration)ms")
        }
        
        NotificationHelper.signalThreadDbChanged(nil)
    }
    
    // used for incoming messages from GCM too
    func updateThread(_ message:ChatMessage, subject:String?, cidArray:[String]? ) throws {
        let csv = cidArrayToString( cidArray )
        try updateThread(message,subject:subject,cids:csv)
    }
    
    func updateThread(_ message:ChatMessage, subject:String?, cids:String? ) throws {
        
        // ugh - handling four variations of a common query
        var sql:String
        var params:[Binding?] = []
        
        var body = message.body
        if body == nil && message.hasImage() {
            body = "posted a picture".localized
        }
        
        if cids == nil {
            if subject == nil {
                sql = UpdateThread.V1
                params = [body,message.from,message.created,message.tid]
            } else {
                sql = UpdateThread.V2
                params = [body,message.from,message.created,subject,message.tid]
            }
        } else {
            if subject == nil {
                sql = UpdateThread.V3
                params = [body,message.from,message.created,cids,message.tid]
            } else {
                sql = UpdateThread.V4
                params = [body,message.from,message.created,cids,subject,message.tid]
            }
        }
        
        if try update( sql, params:params ) == 0 {
            // update failed, so lets insert
            insertThread(body,lastFrom: message.from,updated: message.created, cids:cids, subject: subject,tid: message.tid)
        }
        
        if let tid = message.tid {
            //NotificationHelper.signalMessagesUpdated(tid)
            NotificationHelper.signalThreadDbChanged(tid)
        }
    }
    
    @discardableResult func updateThreadSubject( _ tid:String, subject:String ) throws -> Bool {
        let sql = "UPDATE chats SET subject=? WHERE tid=?"
        let params:[Binding?] = [subject,tid]
        if try update( sql, params:params ) > 0 {
            NotificationHelper.signalThreadDbChanged(tid)
            return true
        } else {
            return false
        }
    }
    
    @discardableResult func updateThread(_ thread:ChatHead) throws -> Bool {
        let cids = cidArrayToString( thread.cids )
        
        let sql = "UPDATE chats SET cids=?,subject=? WHERE tid=?"
        let params:[Binding?] = [cids,thread.subject,thread.tid]
        if try update( sql, params:params ) > 0 {
            NotificationHelper.signalThreadDbChanged(thread.tid)
            return true
        } else {
            return false
        }
    }
    
    @discardableResult func updateSyncTimes( _ tid:String, firstTime:String, lastTime:String ) throws -> Bool {
        let sql = "UPDATE chats SET firstInSync=?,lastInSync=? WHERE tid=?"
        let params:[Binding?] = [firstTime,lastTime,tid]
        return try update( sql, params:params ) > 0
    }
    
    @discardableResult func updateLastSyncTime( _ tid:String, lastTime:String ) throws -> Bool {
        let sql = "UPDATE chats SET lastInSync=? WHERE tid=?"
        let params:[Binding?] = [lastTime,tid]
        return try update( sql, params:params ) > 0
    }
    
    @discardableResult func updateFirstSyncTime( _ tid:String, firstTime:String ) throws -> Bool {
        let sql = "UPDATE chats SET firstInSync=? WHERE tid=?"
        let params:[Binding?] = [firstTime,tid]
        return try update( sql, params:params ) > 0
    }

    //
    // MARK: Utility
    //

    // store cid array as comma separated list or NULL
    fileprivate func cidArrayToString(_ cids:[String]?) -> String? {
        if cids == nil {
            return nil
        } else {
            return cids!.joined(separator: ",")
        }
    }
    
    fileprivate func updateThread(_ lastBody:String?,lastFrom:String?,updated:String?,cids:String?,subject:String?,tid:String?) {
        let params:[Binding?] = [lastBody,lastFrom,updated,cids,subject,tid]
        runSql( UpdateThread.V4, params:params )
    }
    
    fileprivate struct UpdateThread {
        static let V1 = "UPDATE chats SET lastBody=?,lastFrom=?,updated=? WHERE tid=?"
        static let V2 = "UPDATE chats SET lastBody=?,lastFrom=?,updated=?,subject=? WHERE tid=?"
        static let V3 = "UPDATE chats SET lastBody=?,lastFrom=?,updated=?,cids=? WHERE tid=?"
        static let V4 = "UPDATE chats SET lastBody=?,lastFrom=?,updated=?,cids=?,subject=? WHERE tid=?"
    }
    
    fileprivate func insertThread(_ lastBody:String?,lastFrom:String?,updated:String?,cids:String?,subject:String?,tid:String?) {
        let sql = "INSERT INTO chats(lastBody,lastFrom,updated,cids,subject,tid) VALUES(?,?,?,?,?,?)"
        let params:[Binding?] = [lastBody,lastFrom,updated,cids,subject,tid]
        runSql( sql, params:params )
    }
}
