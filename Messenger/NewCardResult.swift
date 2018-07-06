import Foundation
import ObjectMapper

class NewCardResult: BaseResult {
    var cid:String?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        cid <- map["cid"]
    }
}
