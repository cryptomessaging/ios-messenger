import Foundation
import ObjectMapper

class RsvpPreviewResult: BaseResult {
    var rsvp:RsvpRoot?
    var thread:ChatThread?
    var card:Card?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        rsvp <- map["rsvp"]
        thread <- map["thread"]
        card <- map["card"]
    }
}
