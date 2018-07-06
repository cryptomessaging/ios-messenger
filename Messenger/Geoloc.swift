import Foundation
import ObjectMapper
import CoreLocation

class Geoloc: Mappable {
    var lat:Double?
    var lng:Double?
    
    required init?(map: Map) {
    }
    
    required init() {}
    
    init( location:CLLocation ) {
        lat = location.coordinate.latitude
        lng = location.coordinate.longitude
    }
    
    init( lat:Double, lng:Double ) {
        self.lat = lat
        self.lng = lng
    }
    
    func mapping(map: Map) {
        lat <- map["lat"]
        lng <- map["lng"]
    }
}
