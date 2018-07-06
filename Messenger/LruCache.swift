import UIKit
import Haneke
import ObjectMapper

/**
 *  Cache that evicts LRU entries once memory limit hit
 */
class LruCache {

    static let instance = LruCache()
    static let DEBUG = false
    
    fileprivate let stringCache = Shared.stringCache
    fileprivate let imageCache = Shared.imageCache
    fileprivate let webCache = Shared.dataCache    // for sounds, etc.
    
    fileprivate init() {
    }
    
    func clear( exceptImages:Bool, completion:@escaping () -> Void ) {
        stringCache.removeAll {
            self.webCache.removeAll {
                if exceptImages {
                    completion()
                    return
                }
            
                self.imageCache.removeAll {
                    completion()
                }
            }
        }
    }
    
    //===== Sounds and other web resources =====
    
    func saveWebResource(_ url:String, resource:Data ) {
        webCache.set(value: resource, key: url)
    }
    
    func fetchWebResource(_ url:String, onSuccess: @escaping (Data)->(), onFailure: @escaping (Error?)->() ) {
        webCache.fetch(key:url).onFailure( onFailure ).onSuccess( onSuccess )
    }
    
    //===== Cards =====
    
    fileprivate func craftCardCoverKey(_ cid:String,size:String) -> String {
        return "card/\(cid)/cover(\(size))"
    }
    
    fileprivate func craftCardKey(_ cid:String) -> String {
        return "card/\(cid)"
    }
    
    func saveCardCoverImage(_ cid:String, size:String, image:UIImage) {
        let key = craftCardCoverKey(cid,size:size)
        imageCache.set(value: image, key: key)
    }
    
    func fetchCardCoverImage(_ cid:String, size:String, imageView:UIImageView, onSuccess: @escaping (UIImage)->(), onFailure: @escaping (Error?) -> () ) {
        let key = craftCardCoverKey(cid, size:size)
        
        // if its over 24 hours old, fail fetch
        if HanekeHack.isStale(key) {
            onFailure( NSError( domain: "Cache", code: 404, userInfo:nil ) )
        } else {
            imageCache.fetch(key: key).onSuccess( onSuccess ).onFailure(onFailure )
        }
    }
    
    func removeCardCoverImage(_ cid:String, size:String) {
        let key = craftCardCoverKey(cid, size:size)
        imageCache.remove(key: key)
    }

    func saveCard(_ card:Card) {
        let json = Mapper().toJSONString(card, prettyPrint:true)!
        stringCache.set(value: json, key: craftCardKey(card.cid!) )
    }
    
    /*
    func getCard(_ cid:String) -> Card? {
        let json = stringCache.fetch(key: craftCardKey(cid))
        let card = Mapper<Card>().map(JSONString:json)!
        return card
    }*/
    
    func fetchCard(_ cid:String, next:@escaping (Error?,Card?)->Void ) {
        let key = craftCardKey(cid)
        stringCache.fetch(key:key).onSuccess( { json in
            let card = Mapper<Card>().map(JSONString:json)!
            next(nil,card)
        }).onFailure( { failer in
            next(failer,nil)
        })
    }
    
    func removeCard( cid:String ) {
        let key = craftCardKey(cid)
        stringCache.remove(key: key)
    }
    
    // chat images
    
    fileprivate func craftChatImageKey(_ msg:ChatMessage,index:Int,size:String) -> String {
        let key = "chat(\(msg.tid!))created(\(msg.created!))from(\(msg.from!))[\(index)]size(\(size))"
        if( LruCache.DEBUG ) { print( "Chat image key \(key)") }
        return key
    }
    
    func saveChatImage(_ msg:ChatMessage,index:Int,size:String,image:UIImage) {
        let key = craftChatImageKey(msg, index:index, size:size )
        imageCache.set(value: image, key: key)
    }
    
    func fetchChatImage(_ msg:ChatMessage,index:Int,size:String, imageView:UIImageView, onSuccess: @escaping (UIImage)->(), onFailure: @escaping (Error?) -> () ) {
        let key = craftChatImageKey(msg, index:index,size:size )
        imageCache.fetch(key: key).onSuccess( onSuccess ).onFailure(onFailure)
    }
    
    func removeChatImage(_ msg:ChatMessage,index:Int,size:String) {
        let key = craftChatImageKey(msg, index:index, size:size )
        imageCache.remove(key: key)
    }
}
