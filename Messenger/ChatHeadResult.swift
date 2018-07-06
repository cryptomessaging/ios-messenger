import Foundation
import ObjectMapper

class ChatHeadResult: BaseResult {
    var thread: ChatHead?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        thread <- map["thread"]
    }
}
