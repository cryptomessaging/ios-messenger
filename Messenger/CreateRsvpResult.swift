import Foundation
import ObjectMapper

class CreateRsvpResult: BaseResult {
    var cid:String?
    var expires:String?
    var holdover:String?
    var secret:String?
    var max:Int?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        cid <- map["cid"]
        expires <- map["expires"]
        holdover <- map["holdover"]
        secret <- map["secret"]
        max <- map["max"]
    }
}
