import Foundation
import ObjectMapper

class ChildAccountStatusResult: BaseResult {
    var disabled:Bool?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        disabled <- map["disabled"]
    }
}
