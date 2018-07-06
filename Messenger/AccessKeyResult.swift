import Foundation
import ObjectMapper

class AccessKeyResult: BaseResult {
    var accessKey:AccessKey?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        accessKey <- map["accessKey"]
    }
}
