import Foundation
import ObjectMapper

class ChatContact: Mappable {
    var cid:String?
    var tids:[String]?
    
    init() {
    }
    
    init(cid:String,tid:String) {
        self.cid = cid
        self.tids = [ tid ]
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        cid <- map["cid"]
        tids <- map["tids"]
    }
}
