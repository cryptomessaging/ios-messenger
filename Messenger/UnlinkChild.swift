import Foundation
import ObjectMapper

class UnlinkChild: Mappable {
    
    var kidname:String?
    var uid:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        kidname <- map["kidname"]
        uid <- map["uid"]
    }
}
