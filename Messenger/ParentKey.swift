import Foundation
import ObjectMapper

class ParentKey: Mappable {
    var kidname:String?
    var parentEmail:String?
    
    init() {
    }
    
    init(forChild:MyChild) {
        kidname = forChild.kidname
        parentEmail = forChild.parentEmail
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        kidname <- map["kidname"]
        parentEmail <- map["parentEmail"]
    }
}
