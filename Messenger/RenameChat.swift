import Foundation
import ObjectMapper

class RenameChat: Mappable {
    var tid:String?
    var cid:String?
    var subject:String?
    
    init() {
    }
    
    init( tid:String, cid:String, subject:String) {
        self.tid = tid
        self.cid = cid
        self.subject = subject
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        tid <- map["tid"]
        cid <- map["cid"]
        subject <- map["subject"]
    }
}
