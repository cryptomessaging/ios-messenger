import Foundation
import ObjectMapper

class ChatThread: Mappable {
    
    var tid:String?
    var subject:String?
    var hostcids:[String]?
    var cids:[String]?
    var created:String?
    
    init() {
    }
    
    init( cached:CachedThread ) {
        tid = cached.tid
        subject = cached.subject
        cids = StringHelper.asArray( cached.cids )
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        tid <- map["tid"]
        subject <- map["subject"]
        hostcids <- map["hostcids"]
        cids <- map["cids"]
        created <- map["created"]
    }
}
