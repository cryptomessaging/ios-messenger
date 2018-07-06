import Foundation
import ObjectMapper

class DeleteChatMessages: Mappable {
    var cid:String?
    var tid:String?
    var timestamps:[String]?
    
    required init?(map: Map) {
    }
    
    init() {}
    
    func mapping(map: Map) {
        cid <- map["cid"]
        tid <- map["tid"]
        timestamps <- map["timestamps"]
    }
}
