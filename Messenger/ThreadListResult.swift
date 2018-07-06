import Foundation
import ObjectMapper

class ThreadListResult: Mappable {
    var found:[CachedThread]?
    var missing:[String]?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    func mapping(map: Map) {
        found <- map["found"]
        missing <- map["missing"]
    }
}
