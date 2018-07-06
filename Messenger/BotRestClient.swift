import UIKit
import ObjectMapper

//
// Client for talking to a Bot server using HTTP/HTTPS and the CB-HMAC authorization scheme
// Mappable so we can persist to disk
//

class BotRestClient: Mappable {
    
    fileprivate let EMPTY_BODY = EmptyBody()
    static let DEBUG = false
    
    struct Method {
        static let POST = "POST"
        static let GET = "GET"
        static let PUT = "PUT"
        static let DELETE = "DELETE"
    }
    
    fileprivate var urlSession: URLSession
    
    fileprivate(set) var mycid:String?       // might be nil if no user is known
    fileprivate var privateKey:Crypto?
    fileprivate(set) var tid:String?
    fileprivate(set) var botcid:String?
    fileprivate var metapage:MetapageResult?
    fileprivate(set) var key:String
    
    fileprivate(set) var baseUrl: URL?
    
    init() {
        urlSession = URLSession.shared
        key = "?:?:?"    }
    
    required init?(map: Map) {
        urlSession = URLSession.shared
        key = "?:?:?"
    }
    
    func mapping(map: Map) {
        mycid <- map["mycid"]
        privateKey <- map["privateKey"]
        tid <- map["tid"]
        metapage <- map["metapage"]
        key <- map["key"]
        baseUrl <- (map["baseUrl"], URLTransform())
    }
    
    init( baseUrl:URL ) {
        urlSession = URLSession.shared
        key = "?:?:?"
        self.baseUrl = baseUrl
    }
    
    init( mycid:String?, privateKey:Crypto?, tid:String?, botCard:Card, metapage:MetapageResult ) {
        urlSession = URLSession.shared
        
        self.mycid = mycid
        self.botcid = botCard.cid
        self.privateKey = privateKey
        self.tid = tid
        self.metapage = metapage
        
        // unique key for this rest client, same across instantiations
        self.key = BotHelper.keyFor(tid:tid, mycid:mycid, botcid:botCard.cid! )
        
        self.baseUrl = BotHelper.baseUrl( botCard, metapage:metapage )
        
        DebugLogger.instance.append( function:"BotRestClient.init", message:" mycid:\(String(describing: mycid)) tid:\(String(describing: tid)) botcid:\(String(describing: botcid))" )
    }
    
    //
    // MARK: Methods
    //
    
    func fetchMetapage(_ url:String, callback:@escaping (MetapageResult) -> Void ) {
        httpFetch(Method.GET, path:url, secure:false, callback:callback )
    }
    
    func fetchPublicKeys(_ url:String, callback:@escaping (CryptoSetResult) -> Void ) {
        httpFetch(Method.GET, path:url, secure:false, callback:callback )
    }
    
    func fetchHTML( _ path:String, secure:Bool, callback:@escaping (Failure?,String?) -> Void ) {
        httpString(Method.GET, path:path, secure:secure, content:nil, contentType:nil, callback:callback )
    }
    
    //
    // MARK: Utility methods
    //
    
    fileprivate func httpPost<N:Mappable,T:BaseResult>(_ path:String, secure:Bool, body:N, callback:@escaping (T) -> Void) {
        httpUpdate( Method.POST, path:path, secure:secure, body:body, callback:callback )
    }
    
    // Used for POST and PUT
    fileprivate func httpUpdate<N:Mappable,T:BaseResult>(_ method:String, path:String, secure:Bool, body:N, callback:@escaping (T) -> Void) {
        let json = body is EmptyBody ? nil : Mapper().toJSONString(body, prettyPrint:true)
        httpString(method, path:path, secure:secure, content:json, contentType:"application/json" ) {
            (failure,body) -> Void in
            self.processResult( failure:failure, body:body, path:path, callback:callback )
            
            /*var result:T
            if failure != nil {
                result = T()
                result.failure = failure
            } else {
                result = Mapper<T>().map(JSONString:body!)!
            }
            callback(result)*/
        }
    }
    
    func httpFetch<T:BaseResult>(_ method:String, path:String, secure:Bool, callback:@escaping (T) -> Void) {
        httpString(method, path:path, secure:secure, content:nil, contentType:nil ) {
            (failure,body) -> Void in
            self.processResult( failure:failure, body:body, path:path, callback:callback )
            
            /*var result:T
            if failure != nil {
                result = T()
                result.failure = failure
            } else {
                result = Mapper<T>().map(JSONString:body!)
            }
            callback(result)*/
        }
    }
    
    fileprivate func processResult<T:BaseResult>(failure:Failure?, body:String?, path:String, callback:@escaping (T) -> Void ) {
        if failure != nil {
            let result = T()
            result.failure = failure
            callback(result)
        } else {
            if let result = Mapper<T>().map(JSONString:body!) {
                callback( result )
            } else {
                // failed to map body into JSON
                let result = T()
                let message = String( format:"Failed to parse JSON from %@ (Error)".localized, path )
                result.failure = Failure(message:message, details: ["Body: \(String(describing: body))"] )
                callback(result)
            }
        }
    }
    
    fileprivate func parseFailure(data:Data) -> Failure? {
        if let body = String( data:data, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue) ) {
            if let baseResult = Mapper<BaseResult>().map(JSONString:body) {
                return baseResult.failure
            }
        }
        
        return nil
    }
    
    func httpString(_ method:String, path:String, secure:Bool, content:String?, contentType:String?, callback:@escaping (Failure?,String?) -> Void ) {
        http(method, path:path, secure:secure, content:content, contentType:contentType ) { failure, data, response in
            if failure != nil {
                callback(failure,nil)
            } else {
                let result = String(data: data!, encoding:String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                if BotRestClient.DEBUG { print( "BRC Body is \(String(describing: result))") }
                callback(nil,result)
            }
        }
    }
    
    // push the request processing into the background
    fileprivate func http(_ method:String, path:String, secure:Bool, content:String?, contentType:String?, callback:@escaping (Failure?,Data?,URLResponse?) -> Void ) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            self.http2( method, path:path, secure:secure, content:content, contentType: contentType, callback:callback )
        }
    }
    
    fileprivate func http2(_ method:String, path:String, secure:Bool, content:String?, contentType:String?, callback:@escaping (Failure?,Data?,URLResponse?) -> Void ) {
        // is the path relative?
        let url:URL
        if let base = baseUrl {
            guard let u = BotHelper.resolveUrl( path, relativeToUrl: base ) else {
                let message = String(format: "Failed to resolve URL from %@ and %@".localized, path, base as CVarArg )
                let failure = Failure(message: message )
                self.logFailure( failure, url:nil )
                callback(failure,nil,nil)
                return
            }
            url = u
        } else {
            url = URL( string:path )!
        }
        
        // sanity
        if( BotHelper.isWellFormed( url ) != true ) {
            let message = String(format: "URL is not well formed %@".localized, url as CVarArg )
            let failure = Failure(message:message )
            self.logFailure( failure, url:url )
            callback(failure,nil,nil)
            return
        }
        
        let request = NSMutableURLRequest(url: url)
        if BotRestClient.DEBUG {
            print( "BotRestClient requesting \(request)")
        }
        request.httpMethod = method
        
        var diffie:DiffieHellman!
        if secure {
            var host:String
            let port = (url as NSURL).port
            if port == nil || port == 80 || port == -1 {
                host = url.host!
            } else {
                host = "\(url.host!):\(port!)"
            }
            host = host.lowercased()
            
            let fullpath = extractPath( url.relativeString )
            /*var fullpath = url.path
            if let query = url.query {
                fullpath += "?" + query
            }*/
            let botCryptos = metapage?.publicKeys?.cryptos
            diffie = DiffieHellman( method:method, path:fullpath, host:host, mycid:mycid, myPrivateKey:privateKey, tid:tid, botPublicKeys:botCryptos )
            if let failure = diffie.start() {
                self.logFailure( failure, url:url )
                callback(failure,nil,nil)
                return
            }
        }
        
        if content != nil {
            let type = contentType ?? "application/json"
            request.addValue(type, forHTTPHeaderField: "Content-Type")
            let data: Data = content!.data(using: String.Encoding.utf8)!
            request.httpBody = data

            diffie?.update( data )
        }
        
        if secure {
            request.addValue(diffie!.getDate(), forHTTPHeaderField: "X-Mobido-Date")
            request.addValue(diffie!.getAuthorization(), forHTTPHeaderField: "X-Mobido-Authorization")
        }
        
        let task = urlSession.dataTask(with: request as URLRequest, completionHandler: {
            (data,response,error) -> Void in
            
            // networking problem?
            if let error = error {
                let failure = Failure(message: error.localizedDescription, details:[url.absoluteString])
                self.logFailure( failure, url:url )
                callback(failure,nil,nil)
                return
            }
            
            // HTTP response problem?
            let httpResponse = response as? HTTPURLResponse
            if httpResponse == nil {
                // strange
                let failure = Failure(message:"HTTP response is irregular".localized)
                self.logFailure( failure, url:url )
                callback(failure,nil,nil)
                return
            }
            
            let code = httpResponse!.statusCode
            if code != 200 {
                // can we map response body into failure?
                if let data = data, let failure = self.parseFailure( data:data ) {
                    if failure.statusCode == 401 {
                        failure.statusCode = 0
                    }
                    self.logFailure( failure, url:url )
                    callback(failure,nil,nil)    // scrub 401s so they dont cause login
                } else {
                    let message = HTTPURLResponse.localizedString(forStatusCode: httpResponse!.statusCode)
                    let failure = Failure(statusCode: code == 401 ? 0 : code, message:message)
                    self.logFailure( failure, url:url )
                    callback(failure,nil,nil)    // scrub 401s so they dont cause login
                }
            } else {
                DebugLogger.instance.append( "SUCCESS: \(url)" )
                callback(nil,data,response)
            }
        }) 
        DebugLogger.instance.append( "\(task.taskIdentifier) \(method) \(url)" )
        task.resume()
    }
    
    fileprivate func extractPath( _ url:String ) -> String {
        let fullurl = url.characters
        var slashCount = 0
        for (index,c) in fullurl.enumerated() {
            if c == "/" {
                slashCount = slashCount + 1
                if slashCount == 3 {
                    let pos = fullurl.index(fullurl.startIndex, offsetBy:index)
                    let result = fullurl.suffix(from:pos)
                    return String(result)
                }
            }
        }
        
        return url
    }
    
    fileprivate func logFailure( _ failure:Failure, url:URL? ) {
        DebugLogger.instance.append( "FAILURE: \(String(describing: failure.statusCode)) \(String(describing: failure.message)) \(String(describing: url))" )
    }
}
