import Foundation
import ObjectMapper

class ChatSummary: Mappable {
    var cids:[String]?
    var subject:String?
    
    var msg:LatestChatMessage?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        cids <- map["cids"]
        subject <- map["subject"]
        msg <- map["msg"]
    }
}
