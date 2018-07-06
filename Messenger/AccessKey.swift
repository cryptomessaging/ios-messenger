import Foundation
import ObjectMapper

class AccessKey: Mappable {
    var id:String?
    var secret:String?
    var acm:[String:String]?
    
    init?(id:String?, secret:String?, acm:[String:String]? ) {
        self.id = id
        self.secret = secret
        self.acm = acm
        
        if id == nil || id!.isEmpty || secret == nil || secret!.isEmpty {
            return nil
        }
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        id <- map["id"]
        secret <- map["secret"]
        acm <- map["acm"]
    }
    
    func isValid() -> Bool {
        return id != nil && secret != nil
    }
}
