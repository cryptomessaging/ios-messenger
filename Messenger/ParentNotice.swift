import Foundation
import ObjectMapper

class ParentNotice: Mappable {
    var kidname:String?
    var parentEmail:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        kidname <- map["kidname"]
        parentEmail <- map["parentEmail"]
    }
}
