import Foundation
import ObjectMapper

class MetapageResult: BaseResult {
    
    var nickname: String?
    var rebaseUrl: String?
    var widget: WidgetDetail?
    var homepage: WebpageDetail?
    var publicKeys: PublicKeys?
    var aboutpage: WebpageDetail?
    
    required init() {
        super.init()
    }
    
    required init?(map: Map) {
        super.init(map:map)
    }
    
    override func mapping(map: Map) {
        super.mapping(map: map)
        nickname <- map["nickname"]
        rebaseUrl <- map["rebaseUrl"]
        widget <- map["widget"]
        homepage <- map["homepage"]
        aboutpage <- map["aboutpage"]
        publicKeys <- map["publicKeys"]
    }
}
