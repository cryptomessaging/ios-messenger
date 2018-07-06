import Foundation
import ObjectMapper

class ChatMessage: Mappable {
    var from:String?         // sender cid
    var created:String?      // 8601 format
    var body:String?         // message, assuming text for now
    var tid:String?          // thread this is part of
    var media:[Media]?
    var meta:[String:AnyObject]?   // JSON encoded meta info, specific to sender/from
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    required init(tid:String,from:String,created:String,body:String?,media:[Media]?) {
        self.tid = tid
        self.from = from
        self.created = created
        self.body = body
        self.media = media
    }
    
    func mapping(map: Map) {
        from <- map["from"]
        created <- map["created"]
        body <- map["body"]
        media <- map["media"]
        tid <- map["tid"]
        meta <- map["meta"]
    }
    
    func hasImage() -> Bool {
        if let media = media {
            for m in media {
                if let type = m.type {
                    if type.hasPrefix( "image/" ) {
                        return true
                    }
                }
            }
            
            // failed to find an image
            return false
        } else {
            return false
        }
    }
}
