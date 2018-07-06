import Foundation
import ObjectMapper

class AddContactsResult: BaseResult {
    var cards:[Card]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        cards <- map["cards"]
    }
}
