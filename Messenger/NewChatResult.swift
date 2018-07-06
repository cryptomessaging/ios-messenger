import Foundation
import ObjectMapper

class NewChatResult: BaseResult {
    var thread:ChatThread?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        thread <- map["thread"]
    }
}
