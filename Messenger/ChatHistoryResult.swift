import Foundation
import ObjectMapper

class ChatHistoryResult: BaseResult {
    var threads: [String: ChatSummary ]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        threads <- map["threads"]
    }
}
