import Foundation
import WebKit

class BotHelper {
    
    // global way of naming tid/mycid/botcid relationships
    class func keyFor( tid:String?, mycid:String?, botcid:String ) -> String {
        return "tid(\(tid == nil ? "?" : tid!))mycid(\(mycid == nil ? "?" : mycid!))botcid(\(botcid))"
    }
    
    class func isWellFormed( _ url:URL ) -> Bool {        
        if url.host == nil {
            return false
        }
        
        return true
    }
    
    class func loadMetapage( _ botCard:Card, completion:@escaping (MetapageResult,URL?)->Void ) {
        // TODO check cache
        if let metaurl = getMetaUrl(botCard) {
            let restClient = BotRestClient()
            restClient.fetchMetapage(metaurl.absoluteString ) {
                result in
                
                if result.isFailure() {
                    completion(result,metaurl);
                } else {
                    loadPublicKeys( restClient, metaurl: metaurl, metapageResult: result, completion: completion )
                }
            }
        } else {
            let result = MetapageResult()
            result.failure = Failure( message: "Missing metapage URL".localized )
            completion( result, nil )
        }
    }
    
    // After loading the metapage, load the public keys if they are available
    fileprivate class func loadPublicKeys( _ restClient:BotRestClient, metaurl:URL, metapageResult:MetapageResult, completion:@escaping (MetapageResult,URL?)->Void ) {
        
        // do we need to load the public keys?
        guard let publicKeys = metapageResult.publicKeys else {
            // nothing more to do
            completion( metapageResult, metaurl )
            return
        }
        
        // do we already have the keys, or no URL to fetch them?
        if publicKeys.cryptos != nil || publicKeys.url == nil {
            // nothing more to do
            completion( metapageResult, metaurl )
            return
        }
        
        if let keysUrl = resolveUrl( publicKeys.url!, relativeToUrl: metaurl ) {
            restClient.fetchPublicKeys( keysUrl.absoluteString ) {
                keyResult in
                
                if keyResult.isFailure() {
                    // transfer failure, TODO is this a good idea? might be confusing
                    metapageResult.failure = keyResult.failure
                } else {
                    // transfer over public keys
                    publicKeys.cryptos = keyResult.cryptos
                }
                completion(metapageResult, metaurl )
            }
        } else {
            completion( metapageResult, metaurl )
        }
    }
    
    class func getMetaUrl( _ card:Card ) -> URL? {
        // path might be a relative URL which means its provided by default mobido bot server
        if let path = card.metaurl {
            let lower = path.lowercased()
            if lower.hasPrefix("http:") || lower.hasPrefix("https:") {
                return handleBotProxy( handleImpliedManifest( path ) )     // already fully qualified
            }
            
            let host = "http://bots.mobido.com" // TODO switch to HTTPS
            let url = "\(host)/a/\(path)/\(path).json"
            return handleBotProxy( handleImpliedManifest( url ) )
        }
        
        return nil
    }
    
    class func handleImpliedManifest( _ url:String ) -> String {
        if url.hasSuffix("/") {
            return "\(url)manifest.json"
        } else {
            return url
        }
    }
    
    class func handleBotProxy(_ url:String) -> URL? {
        let prefs = MyUserDefaults.instance
        if let pattern = prefs.get( .BOT_PROXY_PATTERN ) {
            if let replacement = prefs.get( .BOT_PROXY_REPLACEMENT ) {
                let modified = url.replacingOccurrences(of: pattern, with: replacement )
                return URL( string:modified )
            } else {
                // huh?! pattern BUT NO REPLACEMENT... :(
                return URL( string:url )
            }
        } else {
            // no pattern
            return URL( string:url )
        }
    }
    
    // Provides the base URL for all requests to a bot.  This is
    // usually the url of the bot manifest file, but the manifest can modify it with 
    // the rebaseUrl.
    class func baseUrl( _ botCard:Card, metapage: MetapageResult ) -> URL? {
        if let metaurl = getMetaUrl( botCard ) {
            if let rebase = metapage.rebaseUrl {
                return resolveUrl( rebase, relativeToUrl:metaurl )
            } else {
                return metaurl
            }
        }
        
        return nil
    }
    
    class func resolveUrl( _ path:String, relativeToUrl url: URL ) -> URL? {
        if let complex = URL( string:path, relativeTo: url ) {
            if let abs = URL( string: complex.absoluteString ) {
                return abs
            }
        }
        
        return nil
    }
    
    class func createUserContentController( /*_ scriptMessageHandler:ScriptMessageHandler? = nil */ ) -> WKUserContentController? {
        
        if let js = loadBotJavascriptApi() {
            let ucc = WKUserContentController()
            
            // add mobido bot api
            let script = WKUserScript(source: js,
                                      injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false )
            ucc.addUserScript( script )
            
            /* register api callbacks
            if let smh = scriptMessageHandler {
                smh.addHandlers(ucc)
            }*/
            
            return ucc
        }
        
        return nil
    }
    
    class func loadBotJavascriptApi() -> String? {
        if let path = Bundle.main.path(forResource: "mobido-bot-widget-api", ofType:"js", inDirectory:"html") {
            do {
                return try String(contentsOfFile:path, encoding: String.Encoding.utf8)
            } catch {
                print( "Failed to load bot API \(error)")
            }
        }
        
        return nil
    }
}
