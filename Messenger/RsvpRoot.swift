import Foundation
import ObjectMapper

class RsvpRoot: Mappable {
    
    var keys:[String: String]?
    var expires:String?
    var max:Int?
    var secret:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        keys <- map["keys"]
        expires <- map["expires"]
        max <- map["max"]
        secret <- map["secret"]
    }
}
