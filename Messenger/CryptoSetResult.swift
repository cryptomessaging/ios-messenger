import Foundation
import ObjectMapper

class CryptoSetResult: BaseResult {
    var cryptos:[String: Crypto]?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        cryptos <- map["cryptos"]
    }
}
