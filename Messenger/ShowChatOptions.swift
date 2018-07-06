import Foundation
import ObjectMapper

class ShowChatOptions: Mappable {
    
    var tid:String?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        tid <- map["tid"]
    }
}
