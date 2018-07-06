import Foundation
import ObjectMapper

class CachedThread: Mappable {
    var tid:String?
    var cids:String?     // comma delimited
    var subject:String?
    var updated:String?  // usually same as msg.created
    
    var firstInSync:String? // time of earliest/oldest message known to be synced.  May be null
    var lastInSync:String?  // time of most recent/latest message known to be synced.  May be null
    
    var msg:LatestChatMessage?
    
    init() {
    }
    
    init( src:ChatThread ) {
        tid = src.tid
        cids = StringHelper.toCsv(src.cids)
        subject = src.subject
        updated = src.created
    }
    
    init(tid:String?,cids:String?,subject:String?,updated:String?,msg:LatestChatMessage?) {
        self.tid = tid
        self.cids = cids
        self.subject = subject
        self.updated = updated
        
        self.msg = msg
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        tid <- map["tid"]
        cids <- map["cids"]
        subject <- map["subject"]
        updated <- map["updated"]
        
        msg <- map["msg"]
    }
    
    func isEqual( _ peer:CachedThread? ) -> Bool {
        if let t2 = peer {
            if LatestChatMessage.isEqual( msg, m2:t2.msg ) != true {
                return false
            }

            return
                StringHelper.isEqual(tid,s2:t2.tid) &&
                StringHelper.isEqual(cids,s2:t2.cids) &&
                StringHelper.isEqual(subject,s2:t2.subject) &&
                StringHelper.isEqual(updated,s2:t2.updated)
        } else {
            return false
        }
    }
}
