import Foundation
import ObjectMapper

class MarketListingsResult: BaseResult {
    
    var listings: [MarketListing]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        
        listings <- map["listings"]
    }
}
