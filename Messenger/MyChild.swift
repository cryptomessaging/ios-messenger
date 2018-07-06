import Foundation
import ObjectMapper

class MyChild: Mappable {
    var uid:String?
    var kidname:String?
    var birthday:String?
    var parentEmail:String?
    var acm:[String:String]?  // { coppa:'consented' }
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func acmValue( _ key:String, def:String? = nil ) -> String? {
        if let acm = acm {
            if let value = acm[key] {
                return value
            }
        }
        
        return def
    }
    
    func mapping(map: Map) {
        uid <- map["uid"]
        kidname <- map["kidname"]
        birthday <- map["birthday"]
        parentEmail <- map["parentEmail"]
        acm <- map["acm"]
    }
}
