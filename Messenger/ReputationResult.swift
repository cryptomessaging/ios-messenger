import Foundation
import ObjectMapper

class ReputationResult: BaseResult {
    var reputations:[String: Reputation]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        reputations <- map["reputations"]
    }
}
