import Foundation
import ObjectMapper

class ChatHead: Mappable {
    var tid:String?
    var cids:[String]?
    var subject:String?
    var created:String? // ISO8601
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        tid <- map["tid"]
        cids <- map["cids"]
        subject <- map["subject"]
        created <- map["created"]
    }
}
