import Foundation
import ObjectMapper

class MetaUrlUpdate: Mappable {
    
    var metaurl:String?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        metaurl <- map["metaurl"]
    }
}
