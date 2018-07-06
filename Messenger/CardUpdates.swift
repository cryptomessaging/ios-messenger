import Foundation
import ObjectMapper

class CardUpdates: Mappable {
    var cid:String?
    var nickname:String?
    var tagline:String?
    var rids:[String]?
    var media:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        cid <- map["cid"]
        nickname <- map["nickname"]
        tagline <- map["tagline"]
        rids <- map["rids"]
        media <- map["media"]
    }
}
