import Foundation
import ObjectMapper

class CardHelper {
    
    static let DEBUG = false
    
    //
    // Utility
    //
    
    class func findCard(_ cid:String?, inCards cards:[Card]) -> Card? {
        if let i = findCardIndex(cid, inCards:cards ) {
            return cards[i]
        } else {
            return nil
        }
    }
    
    class func findCards( _ cids:Set<String>, inCards cards:[Card] ) -> [Card] {
        var result = [Card]()
        
        for c in cards {
            if cids.contains( c.cid! ) {
                result.append( c )
            }
        }

        return result
    }
    
    class func findCardIndex(_ cid:String?, inCards:[Card]) -> Int? {
        if let cardid = cid {
            for (index,c) in inCards.enumerated() {
                if cardid == c.cid {
                    return index
                }
            }
        }
        
        return nil
    }
    
    class func getCardIds(_ cards:[Card]) -> Set<String> {
        var result:Set<String> = Set()
        for c in cards {
            result.insert(c.cid!)
        }
        return result
    }
    
    class func getThreadCardIds(_ thread:CachedThread) -> [String] {
        return StringHelper.asArray(thread.cids) ?? [String]()
    }
    
    class func resolveReputations( _ card:Card, reputations:[String: Reputation]? ) {
        card.reputations = []   // reset
        
        if CardHelper.DEBUG {
            let cardJson = card.toJSONString(prettyPrint: true)
            var repJson:Any?
            if let reps = reputations {
                repJson = Mapper().toJSONDictionary(reps)
            }
            print( "resolveReputations() for card \(String(describing: cardJson)) with reps \(String(describing: repJson))")
        }
        
        if let reps = reputations {
            if let rids = card.rids {
                for id in rids {
                    if let r = reps[id] {
                        card.reputations!.append( r )
                    }
                }
            }
        }
        
        if CardHelper.DEBUG {
            let cardJson = card.toJSONString(prettyPrint: true)
            print( "resolveReputations() result \(String(describing: cardJson))")
        }
    }
    
    //
    // Cache aware loaders, fallback to REST fetch when necessary
    //
    
    class func loadMyPrivateKey( _ mycid:String, type:String, completion:@escaping (_ failure:Failure?,_ privateKey:Crypto?)->Void ) {
        if let privateKey = MyUserDefaults.instance.getCardPrivateKey(mycid, type:type ) {
            completion(nil, privateKey )
        } else {
            MobidoRestClient.instance.fetchMyCardPrivateKey( mycid, type:type ) {
                result in
                
                if let privateKey = result.crypto {
                    MyUserDefaults.instance.setCardPrivateKey(mycid, privateKey: privateKey )
                }
                
                completion(result.failure, result.crypto)
            }
        }
    }
    
    //
    // REST methods
    //
    
    // NOTE: This silently swallows errors :(
    class func fetchThreadCard(_ tid:String, cid:String, callback:@escaping (Card) -> Void ) {
        // maybe it's already in our cache?
        let cache = LruCache.instance
        cache.fetchCard(cid) { (error,card) in
            // ignore the error :(
            if let c = card {
                callback(c)
            } else {
                // we need to fetch from server
                MobidoRestClient.instance.fetchThreadCard(tid, cid:cid ) {
                    result in
                    if let card = result.card {
                        cache.saveCard(card)
                        callback(card)
                    }
                }
            }
        }
    }
    
    // Public or one of my cards, does not need thread context
    class func fetchPublicCard(_ cid:String, completion:@escaping (Card?,Failure?) -> Void ) {
        // maybe it's already in our cache?
        let cache = LruCache.instance
        cache.fetchCard(cid) { (error,card) in
            // ignore the cache error
            if let c = card {
                completion(c,nil)
                return
            }
            
            // we need to fetch from server
            MobidoRestClient.instance.fetchCard(cid ) {
                result in
                
                if let card = result.card {
                    cache.saveCard(card)
                }
                completion(result.card,result.failure)
            }
        }
    }
}
