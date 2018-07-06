import Foundation
import ObjectMapper

class WidgetDetail: Mappable {
    
    var type:String?
    var url:String?    // can be relative to the bot manifest
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        type <- map["type"]
        url <- map["url"]
    }
}
