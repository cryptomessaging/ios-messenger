import Foundation
import ObjectMapper

class NewAccount: Mappable {
    var authority:String?
    var id:String?
    var password:String?
    var login:Bool?
    var birthday:String?    // as YYYY-MM-DD
    
    // For parent consent
    var kidname:String?
    var parentEmail:String?
    
    required init?(map: Map) {
    }
    
    init(authority:String,id:String,password:String,login:Bool) {
        self.authority = authority
        self.id = id
        self.password = password
        self.login = login
    }
    
    func mapping(map: Map) {
        authority <- map["authority"]
        id <- map["id"]
        password <- map["password"]
        login <- map["login"]
        birthday <- map["birthday"]
        
        kidname <- map["kidname"]
        parentEmail <- map["parentEmail"]
    }
}
