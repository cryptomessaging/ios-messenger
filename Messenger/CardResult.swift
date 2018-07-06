import Foundation
import ObjectMapper

class CardResult: BaseResult {
    var card:Card?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        card <- map["card"]
    }
}
