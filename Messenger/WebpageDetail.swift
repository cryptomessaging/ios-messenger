import Foundation
import ObjectMapper

class WebpageDetail: Mappable {
    
    var url:String?    // can be relative to the bot manifest
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        url <- map["url"]
    }
}
