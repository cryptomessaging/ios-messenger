import Foundation
import ObjectMapper

class CryptoResult: BaseResult {
    
    var crypto: Crypto?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        crypto <- map["crypto"]
    }
}
