import Foundation
import ObjectMapper

class ParentConsent: Mappable {
    var kidname:String?
    var parentEmail:String?
    var media:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        kidname <- map["kidname"]
        parentEmail <- map["parentEmail"]
        media <- map["media"]
    }
}
