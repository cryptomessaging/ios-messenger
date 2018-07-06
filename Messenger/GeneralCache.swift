import Foundation
import ObjectMapper

class UserReputations: Mappable {
    var reputations:[String: Reputation]?
    
    required init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        reputations <- map["reputations"]
    }
}

class MarketList: Mappable {
    var listings:[MarketListing]!
    var created:Date!
    
    required init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        listings <- map["listings"]
        created <- (map["created"], DateTransform())
    }
}

/**
 *  Cache that saves keyed values to disk as JSON.
 *  This is a NON LRU cache for a handful of things.
 *  TODO make thread safe
 */
class GeneralCache {
    
    fileprivate static let DEBUG = false
    static let instance = GeneralCache()
    fileprivate var documentsDirectory:NSString
    
    fileprivate struct Filename {
        static let MY_CARD_LIST = "my_card_list.json"
        static let MY_REPUTATIONS = "my_reputations.json"
        static let LOCATION_LISTENERS = "location_listeners.json"
    }
    
    fileprivate init() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        documentsDirectory = paths[0] as NSString
    }
    
    func clear() {
        let mgr = FileManager.default
        let files = [Filename.MY_CARD_LIST, Filename.MY_REPUTATIONS, Filename.LOCATION_LISTENERS,
                     marketListFilename(.recommended), marketListFilename(.popular), marketListFilename(.homepage) ]
        for filename in files {
            let path = documentsDirectory.appendingPathComponent(filename)
            if mgr.fileExists(atPath: path) {
                do {
                    try mgr.removeItem(atPath: path)
                    print( "Cleaned out \(path)" )
                } catch {
                    print( "Failed to clean out \(path)" )
                }
            }
        }
    }
    
    func saveMyCardList( _ cards:[Card] ) {
        let json = Mapper().toJSONString(cards)
        saveString(json!, toFilename:Filename.MY_CARD_LIST)
    }
    
    func loadMyCardList() -> [Card]? {
        if let json = loadString(Filename.MY_CARD_LIST) {
            return Mapper<Card>().mapArray( JSONString:json )
        } else {
            return nil
        }
    }
    
    func saveLocationListeners( _ listeners:[ListenerEntry] ) {
        let json = Mapper().toJSONString(listeners)
        saveString(json!, toFilename:Filename.LOCATION_LISTENERS)
    }
    
    func loadLocationListeners() -> [ListenerEntry]? {
        if let json = loadString(Filename.LOCATION_LISTENERS) {
            print( "Loaded location listeners \(json)" )
            return Mapper<ListenerEntry>().mapArray( JSONString:json )
        } else {
            return nil
        }
    }
    
    // Market listings
    
    fileprivate func marketListFilename( _ category:MarketCategory ) -> String {
        return "market_category_\(category.rawValue).json";
    }
    
    func saveMarketListings( _ listings:[MarketListing], category:MarketCategory ) {
        let list = MarketList()
        list.listings = listings
        list.created = Date()
        let json = Mapper().toJSONString(list)!
        saveString(json, toFilename:marketListFilename(category))
    }
    
    func loadMarketListings(_ category:MarketCategory) -> (MarketList)? {
        if let json = loadString(marketListFilename(category)) {
            return Mapper<MarketList>().map( JSONString:json )
        } else {
            return nil
        }
    }
    
    // BotRestClients
    
    fileprivate func botRestClientFilename( _ key:String ) -> String {
        return "bot_rest_client_\(key).json";
    }
    
    func saveBotRestClient( _ client:BotRestClient ) {
        let json = Mapper().toJSONString(client)!
        saveString(json, toFilename:botRestClientFilename(client.key))
    }
    
    func loadBotRestClient( _ key:String) -> (BotRestClient)? {        
        if let json = loadString(botRestClientFilename(key)) {
            return Mapper<BotRestClient>().map( JSONString:json )
        } else {
            return nil
        }
    }
    
    // Reputations
    
    func saveMyReputations( _ reputations:[String: Reputation]? ) {
        let wrapper = UserReputations()
        wrapper.reputations = reputations
        let json = Mapper().toJSONString(wrapper)
        saveString(json!, toFilename:Filename.MY_REPUTATIONS)
    }
    
    func loadMyReputations() -> [String: Reputation]? {
        if let json = loadString(Filename.MY_REPUTATIONS) {
            if let wrapper = Mapper<UserReputations>().map( JSONString:json ) {
                if let reps = wrapper.reputations {
                    return reps
                } else {
                    return [String:Reputation]()
                }
            }
        }
        
        return nil
    }
    
    //
    // MARK: Utility
    //
    
    fileprivate func saveString( _ json:String, toFilename:String ) {
        let path = documentsDirectory.appendingPathComponent(toFilename)
        if GeneralCache.DEBUG { print( "Saving to \(path) of \(json)") }
        do {
            try json.write(toFile: path, atomically: true, encoding:String.Encoding.utf8)
        } catch {
            DebugLogger.instance.append( function:"saveString()", message: "Failed to cache \(path)" )
        }
    }
    
    fileprivate func loadString( _ filename:String ) -> String? {
        let mgr = FileManager.default
        let path = documentsDirectory.appendingPathComponent(filename)
        if !mgr.fileExists(atPath: path) {
            return nil
        }
        
        do {
            let s = try String(contentsOfFile: path, encoding: String.Encoding.utf8)
            if GeneralCache.DEBUG { print( "Loaded from \(path): \(s)") }
            return s
        } catch {
            DebugLogger.instance.append( function:"saveString()", message: "Failed to read \(path) from cache" )
            return nil
        }
    }
}
