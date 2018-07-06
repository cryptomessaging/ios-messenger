import Foundation
import ObjectMapper

class PublicKeys: Mappable {
    
    var url: String?
    var cryptos:[String: Crypto]?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        url <- map["url"]
        cryptos <- map["cryptos"]
    }
}
