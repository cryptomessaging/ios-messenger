import Foundation
import ObjectMapper

class NewPassword: Mappable {
    var password:String?
    
    init() {}
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        password <- map["password"]
    }
}
