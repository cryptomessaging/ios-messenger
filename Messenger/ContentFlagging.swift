import Foundation
import ObjectMapper

class ContentFlagging: Mappable {
    var type:String?
    var id:String?
    var reason:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        type <- map["type"]
        id <- map["id"]
        reason <- map["reason"]
    }
}
