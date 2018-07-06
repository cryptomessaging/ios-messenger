import Foundation
import ObjectMapper

class MyLoginsResult: BaseResult {
    var logins:[LoginState]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map:map)
        logins <- map["logins"]
    }
}
