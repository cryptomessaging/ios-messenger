import Foundation
import ObjectMapper

class MyChildrenResult: BaseResult {
    var children:[MyChild]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        children <- map["children"]
    }
}
