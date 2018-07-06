import Foundation
import ObjectMapper

class NewCard: Mappable {
    var nickname:String?
    var tagline:String?
    var media:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        nickname <- map["nickname"]
        tagline <- map["tagline"]
        media <- map["media"]
    }
}
