import Foundation
import ObjectMapper

class MarketCategoryUpdates: Mappable {
    var categories:[String:String?]?
    var passcode:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        categories <- map["categories"]
        passcode <- map["passcode"]
    }
}
