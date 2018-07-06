import Foundation
import ObjectMapper

class ChatMessageHistoryResult: BaseResult {
    var thread: ChatThread?
    var messages: [ChatMessage]?    // NOT necessarily in order
    var limit: Int?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        thread <- map["thread"]
        messages <- map["messages"]
        limit <- map["limit"]
    }
}
