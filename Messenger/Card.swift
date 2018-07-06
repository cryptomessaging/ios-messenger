import Foundation
import ObjectMapper


protocol HasCardId {
    var cid:String? { get set }
}

class Card: Mappable, HasCardId {
    
    var cid:String?
    var created:String?     // ISO8601
    var updated:String?     // ISO8601
    
    var nickname:String?
    var tagline:String?
    
    var rids:[String]?              // my reputation ids
    // - OR -
    var reputations:[Reputation]?   // ordered reputation details
    
    var metaurl:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    // Any nickname ending in Bot is a bot!
    func isBot() -> Bool {
        if let nick = nickname {
            return nick.hasSuffix("Bot")
        } else {
            return false
        }
    }
    
    /*
    func botUrl() -> String? {
        if let reps = reputations {
            for r in reps {
                if r.type == "boturl" {
                    return r.value
                }
            }
        }
        return nil
    }*/
    
    func mapping(map: Map) {
        cid <- map["cid"]
        created <- map["created"]
        updated <- map["updated"]
        nickname <- map["nickname"]
        tagline <- map["tagline"]
        rids <- map["rids"]
        reputations <- map["reputations"]
        metaurl <- map["metaurl"]
    }
}
