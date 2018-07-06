import Foundation
import ObjectMapper

class CardIdsResult: BaseResult {
    var cids:[String]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        cids <- map["cids"]
    }
}
