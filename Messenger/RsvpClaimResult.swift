import Foundation
import ObjectMapper

class RsvpClaimResult: BaseResult {
    var rsvp: RsvpRoot?
    var cutoff:RsvpCutoff?
    var holdoff:Int?    // seconds to delay before applying claim
    var thread:ChatThread?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        rsvp <- map["rsvp"]
        cutoff <- map["cutoff"]
        holdoff <- map["holdoff"]
        thread <- map["thread"]
    }
}
