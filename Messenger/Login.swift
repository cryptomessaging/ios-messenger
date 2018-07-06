import Foundation
import ObjectMapper

class Login: Mappable {
    var authority:String?
    var id:String?
    var password:String?
    
    required init?(map: Map) {
    }
    
    init(authority:String) {
        self.authority = authority
    }
    
    init(authority:String,id:String) {
        self.authority = authority
        self.id = id
    }
    
    init(authority:String,id:String,password:String) {
        self.authority = authority
        self.id = id
        self.password = password
    }
    
    func mapping(map: Map) {
        authority <- map["authority"]
        id <- map["id"]
        password <- map["password"]
    }
}
