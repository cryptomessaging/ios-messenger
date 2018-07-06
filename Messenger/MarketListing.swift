import Foundation
import ObjectMapper

class MarketListing: Mappable, HasCardId {
    var cid:String?
    var score:Float?
    var categories:[String:String]?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        cid <- map["cid"]
        score <- map["score"]
        categories <- map["categories"]
    }
}
