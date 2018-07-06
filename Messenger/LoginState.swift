import Foundation
import ObjectMapper

class LoginState: Mappable {
    var authority:String?
    var id:String?
    var verified:Bool?  // the (usually email) has been verified
    var owned:Bool?     // I am the owner
    
    required init?(map: Map) {
    }
    
    init() {
    }
    
    func mapping(map: Map) {
        authority <- map["authority"]
        id <- map["id"]
        verified <- map["verified"]
        owned <- map["owned"]
    }
}
