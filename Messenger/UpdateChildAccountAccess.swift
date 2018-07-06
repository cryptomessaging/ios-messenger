import Foundation
import ObjectMapper

class UpdateChildAccountAccess: Mappable {
    var disable:Bool?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        disable <- map["disable"]
    }
}
