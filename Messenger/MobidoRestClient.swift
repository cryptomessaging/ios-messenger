
import UIKit
import ObjectMapper

class EmptyBody: Mappable {
    init() {}
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
    }
}

class MobidoRestClient: NSObject, URLSessionDelegate {
    
    fileprivate let EMPTY_BODY = EmptyBody()
    static let DEBUG = false
    static let instance = MobidoRestClient()
    
    struct Method {
        static let POST = "POST"
        static let GET = "GET"
        static let PUT = "PUT"
        static let DELETE = "DELETE"
    }
    
    fileprivate var urlSession: Foundation.URLSession?
    fileprivate static let apiVersion = "v1"
    
    override init() {
        super.init()
        
        //urlSession = NSURLSession.sharedSession()
        
        let configuration = URLSessionConfiguration.default
        urlSession = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
    }
    
    //============== Helper to download file ==========
    
    func fetch(_ url:URL, callback:@escaping (Failure?,Data?,URLResponse?)->Void ) {
        urlSession?.dataTask(with: url, completionHandler: {
            (data, response, error) in
            
            // networking problem?
            if error != nil {
                let failure = Failure(message: (error?.localizedDescription)!)
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
                let failure = self.parseFailure(url, data:data, response:httpResponse!, error:error as NSError? )
                callback(failure,nil,nil)
            } else {
                DebugLogger.instance.append( "SUCCESS: \(url)" )
                callback(nil,data,response)
            }
        }) .resume()
    }
    
    //============== Track uploads ==========
    
    class ProgressHandlerEntry {
        let created = CFAbsoluteTimeGetCurrent()
        var taskId:Int?
        let progressHandler:(_ totalSent: Int64, _ uploadSize: Int64) -> ()
        
        init( _ progressHandler:@escaping (_ totalSent: Int64, _ uploadSize: Int64) -> () ) {
            self.progressHandler = progressHandler
        }
    }
    
    fileprivate var progressHandlerMap = [Int:ProgressHandlerEntry]()
    
    func URLSession(_ session: Foundation.URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64)
    {
        let taskId = task.taskIdentifier
        if let e = progressHandlerMap[taskId] {
            e.progressHandler(totalBytesSent, totalBytesExpectedToSend )
        }
    }
    
    //============== COPPA etc. =============
    
    func sendParentNotice(_ notice:ParentNotice,callback:@escaping (BaseResult) -> Void) {
        httpPost( "/parent/coppa/directNotice", secure:false, body:notice, callback:callback )
    }
    
    func sendParentConsent(_ consent:ParentConsent, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)?, callback: @escaping (BaseResult) -> Void  ) {
        httpPost("/parent/coppa/consentForm", secure:false, body:consent, progressHandler:progressHandler, callback:callback )
    }
    
    func denyParentConsent( _ parentKey:ParentKey, callback:@escaping (BaseResult) -> Void) {
        httpUpdate( Method.PUT, path:"/parent/coppa/deny", secure:true, body:parentKey, callback:callback )
    }
    
    func unlinkChildAccount( _ unlink:UnlinkChild, callback:@escaping (BaseResult) -> Void) {
        let uid = unlink.uid != nil ? unlink.uid! : "*"
        httpUpdate( Method.PUT, path:"/children/\(uid)/unlink", secure:true, body:unlink, callback:callback )
    }
    
    //== Non-specific ==
    
    func fetchMyChildren(_ callback:@escaping (MyChildrenResult) -> Void) {
        httpFetch(Method.GET, path:"/children", secure:true, callback:callback )
    }
    
    func fetchChildAccountStatus( _ childuid:String, callback:@escaping (ChildAccountStatusResult) -> Void) {
        httpFetch(Method.GET, path:"/children/\(childuid)/status", secure:true, callback:callback )
    }
    
    func updateChildAccountAccess( _ childuid:String, update:UpdateChildAccountAccess, callback:@escaping (BaseResult) -> Void) {
        httpUpdate( Method.PUT, path:"/children/\(childuid)/access", secure:true, body:update, callback:callback )
    }
    
    func deleteChildAccount( _ childuid:String, callback:@escaping (BaseResult) -> Void) {
        httpFetch(Method.DELETE, path:"/children/\(childuid)", secure:true, callback:callback )
    }
    
    func createChildAccessKey( _ childuid:String, callback:@escaping (AccessKeyResult) -> Void) {
        //let login = Login(authority: "foo", id:"bar", password:"shhh" )
        httpPost( "/children/\(childuid)/accessKey", secure:true, body:EMPTY_BODY, callback:callback )
    }
    
    //============== Account/Login ==========
    
    func createAccount(_ account:NewAccount,callback:@escaping (AccessKeyResult) -> Void) {
        httpPost( "/account", secure:false, body:account, callback:callback )
    }
    
    func createAccessKey( _ login:Login, callback:@escaping (AccessKeyResult) -> Void) {
        httpPost( "/account/accessKey", secure:false, body:login, callback:callback )
    }
    
    func createLogin( _ login:Login, callback:@escaping (AccessKeyResult) -> Void) {
        httpPost( "/account/logins", secure:true, body:login, callback:callback )
    }
    
    func fetchMyLogins(_ callback:@escaping (MyLoginsResult) -> Void) {
        httpFetch(Method.GET, path:"/account/logins", secure:true, callback:callback )
    }
    
    func deleteLogin(_ login:Login, callback:@escaping (BaseResult) -> Void) {
        let escapedId = login.id!.addingPercentEncoding( withAllowedCharacters: CharacterSet.urlQueryAllowed )
        httpFetch(Method.DELETE, path:"/account/logins/\(login.authority!):\(escapedId!)", secure:true, callback:callback )
    }
    
    func changePassword( _ password:NewPassword, callback:@escaping (BaseResult) -> Void) {
        httpUpdate( Method.PUT, path:"/account/password", secure:true, body:password, callback:callback )
    }
    
    //============ Content Flagging =========
    
    func flagContent( _ flag:ContentFlagging, callback:@escaping (BaseResult) -> Void) {
        httpPost( "/flagging", secure:true, body:flag, callback:callback )
    }
    
    //================ Market =================
    
    // moved to unsecured endpoints so it can be called before accounts are made
    func fetchMarketListingsByCategory(_ category:MarketCategory, callback:@escaping (MarketListingsResult) -> Void) {
        httpFetch(Method.GET, path:"/market/category/\(category.rawValue)", secure:false, callback:callback )
    }
    
    func removeCardFromMarket(_ cid:String, callback:@escaping (BaseResult) -> Void) {
        httpFetch(Method.DELETE, path:"/cards/\(cid)/market", secure:true, callback:callback )
    }
    
    func updateMarketCategories( _ cid:String, updates:MarketCategoryUpdates, callback:@escaping (BaseResult) -> Void) {
        httpUpdate(Method.PUT, path:"/cards/\(cid)/categories", secure:true, body:updates, callback:callback )
    }
    
    //================= GCM =================
    
    func registerApnToken( _ registrationToken:String, callback:@escaping (BaseResult) -> Void) {
        let token = StringHelper.urlEncode( registrationToken )
        httpFetch(Method.PUT, path:"/channel/apn/token/\(token)", secure:true, callback:callback )
    }

    //================= Cards ===============
    
    // Mine
    
    func createCard(_ card:NewCard, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)?, callback: @escaping (NewCardResult) -> Void  ) {
        httpPost("/cards", secure:true, body:card, progressHandler:progressHandler, callback:callback )
    }

    func updateCard(_ updates:CardUpdates, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)?, callback: @escaping (BaseResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/cards/\(updates.cid!)", secure:true, body:updates, progressHandler:progressHandler, callback:callback )
    }
    
    func setMetaUrl(_ url:String?, cid:String, callback: @escaping (BaseResult) -> Void ) {
        let update = MetaUrlUpdate()
        update.metaurl = url
        httpUpdate( Method.PUT, path:"/cards/\(cid)/metaurl", secure:true, body:update, callback:callback )
    }
    
    func listMyCards(_ callback:@escaping (CardListResult) -> Void) {
        httpFetch(Method.GET, path:"/cards", secure:true, callback:callback )
    }
    
    func deleteCard(_ cid:String, callback:@escaping (BaseResult) -> Void) {
        httpFetch(Method.DELETE, path:"/cards/\(cid)", secure:true, callback:callback )
    }
    
    func fetchMyReputations( _ callback:@escaping (ReputationResult) -> Void ) {
        httpFetch(Method.GET, path:"/reputation", secure:true, callback:callback )
    }
    
    func fetchMyCardPrivateKey( _ mycid:String, type:String, callback:@escaping (CryptoResult) -> Void ) {
        httpFetch(Method.GET, path:"/cards/\(mycid)/privatekey/\(type)", secure:true, callback:callback )
    }
    
    // Public
    
    // also used to fetch my card cover
    func fetchCardCover(_ cid:String, size:String, callback: @escaping (Failure?,Data?,URLResponse?) -> Void ) {
        let path = "/cards/\(cid)/media/cover(\(size)).jpg"
        http(Method.GET, path:path, secure:true, body: nil, callback:callback )
    }
    
    // can also be used to fetch my card
    func fetchCard(_ cid:String, callback:@escaping (CardResult) -> Void ) {
        httpFetch(Method.GET, path:"/cards/\(cid)", secure:true, callback:callback )
    }
    
    // Thread based
    
    func fetchThreadCardCover(_ tid:String, cid:String, size:String, callback: @escaping (Failure?,Data?,URLResponse?) -> Void ) {
        let path = "/cards/\(cid)/inthread/\(tid)/media/cover(\(size)).jpg"
        http(Method.GET, path:path, secure:true, body: nil, callback:callback )
    }

    func fetchThreadCard(_ tid:String, cid:String, callback:@escaping (CardResult) -> Void ) {
        httpFetch(Method.GET, path:"/cards/\(cid)/inthread/\(tid)", secure:true, callback:callback )
    }
    
    //=============== Chat (thread) management ================
    
    func createPublicChat(_ thread:NewPublicChat, callback: @escaping (NewChatResult) -> Void ) {
        httpPost("/chats", secure:true, body:thread, callback:callback )
    }
    
    func createChat(_ thread:NewChat, callback: @escaping (NewChatResult) -> Void ) {
        httpPost("/chats", secure:true, body:thread, callback:callback )
    }
    
    func fetchChatHead(_ tid:String, callback:@escaping (ChatHeadResult) -> Void) {
        httpFetch(Method.GET, path:"/chats/\(tid)", secure:true, callback:callback )
    }
    
    // summary of all my threads
    func fetchChatHistory( _ callback:@escaping (ChatHistoryResult) -> Void ) {
        httpFetch(Method.GET, path:"/chats", secure:true, callback:callback )
    }
    
    func leaveThread(_ tid:String, mycid:String?, callback: @escaping (BaseResult) -> Void ) {
        if let mycid = mycid {
            httpUpdate( Method.PUT, path:"/chats/\(tid)/remove/\(mycid)", secure:true, body:EMPTY_BODY, callback:callback )
        } else {
            leaveThread(tid, callback:callback)
        }
    }
    
    func leaveThread(_ tid:String, callback: @escaping (BaseResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/chats/\(tid)/remove", secure:true, body:EMPTY_BODY, callback:callback )
    }
    
    // used to add bots to thread, and maybe more later...
    func addCardToThread( _ cid:String, tid:String, mycid:String, callback: @escaping (CardResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/chats/\(tid)/add/\(cid)/by/\(mycid)", secure:true, body:EMPTY_BODY, callback:callback )
    }
    
    // add people I know from other chats
    func addContactsToThread(_ contacts:AddContacts, tid:String, callback: @escaping (AddContactsResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/chats/\(tid)/addcontacts", secure:true, body:contacts, callback:callback )
    }
    
    // hosts can remove bots or other people
    func removeCardFromThread( _ cid:String, tid:String, mycid:String, callback: @escaping (BaseResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/chats/\(tid)/remove/\(cid)/by/\(mycid)", secure:true, body:EMPTY_BODY, callback:callback )
    }
    
    func deleteThread(_ tid:String, callback:@escaping (BaseResult) -> Void) {
        httpFetch(Method.DELETE, path:"/chats/\(tid)", secure:true, callback:callback )
    }
    
    func renameThread(_ rename:RenameChat, callback: @escaping (BaseResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/chats/\(rename.tid!)/rename", secure:true, body:rename, callback:callback )
    }
    
    //============== Chat (thread) messages ==================
    
    func sendChatMessage(_ tid:String, message:ChatMessage, callback:@escaping (ChatMessageOutResult) -> Void) {
        httpPost("/chats/\(tid)/messages", secure:true, body:message, callback:callback )
    }
    
    // Most recent messages - 500 or so...
    func fetchChatMessages( _ tid:String, callback:@escaping (ChatMessageHistoryResult) -> Void ) {
        httpFetch(Method.GET, path:"/chats/\(tid)/messages", secure:true, callback:callback )
    }
    
    // gets messages after a time, but messages are returned newest first, and this method
    // may need to be called repeatedly
    func fetchChatMessages( _ tid:String, afterTime:String, callback:@escaping (ChatMessageHistoryResult) -> Void ) {
        httpFetch(Method.GET, path:"/chats/\(tid)/messages/after/\(afterTime)", secure:true, callback:callback )
    }
    
    // returns messages in reverse chonological order
    func fetchChatMessages( _ tid:String, beforeTime:String, callback:@escaping (ChatMessageHistoryResult) -> Void ) {
        httpFetch(Method.GET, path:"/chats/\(tid)/messages/before/\(beforeTime)", secure:true, callback:callback )
    }
    
    // returns messages in reverse chonological order
    func fetchChatMessages( _ tid:String, startTime:String, endTime:String, callback:@escaping (ChatMessageHistoryResult) -> Void ) {
        httpFetch(Method.GET, path:"/chats/\(tid)/messages/between/\(startTime)/to/\(endTime)", secure:true, callback:callback )
    }
    
    func fetchChatMedia(_ tid:String, cid:String, created:String, index:Int, size:String, callback: @escaping (Failure?,Data?,URLResponse?) -> Void ) {
        let path = "/chats/\(tid)/messages/from/\(cid)/at/\(created)/media/\(index)/size/\(size)"
        http(Method.GET, path:path, secure:true, body:nil, callback:callback )
    }
    
    func deleteMessages(_ messages:DeleteChatMessages, callback:@escaping (BaseResult) -> Void) {
        httpUpdate(Method.PUT, path:"/chats/\(messages.tid!)/messages", secure:true, body:messages, callback:callback )
    }
    
    //================ RSVPs ===================
    
    func createRsvp( _ rsvp:NewRsvp, callback:@escaping (CreateRsvpResult) -> Void) {
        httpPost("/connect/rsvp", secure:true, body:rsvp, callback:callback )
    }
    
    func fetchRsvpPreview( _ secret:String, callback:@escaping (RsvpPreviewResult) -> Void ) {
        httpFetch(Method.GET, path:"/connect/rsvp/\(secret)", secure:true, callback:callback )
    }
    
    func claimRsvpOffer( _ secret:String, mycid:String, callback: @escaping (RsvpClaimResult) -> Void ) {
        httpUpdate( Method.PUT, path:"/connect/rsvp/\(secret)/card/\(mycid)", secure:true, body:EMPTY_BODY, callback:callback )
    }
    
    func applyRsvpOffer( _ secret:String, mycid:String, callback: @escaping (RsvpClaimResult) -> Void ) {
        httpFetch( Method.GET, path:"/connect/rsvp/\(secret)/card/\(mycid)", secure:true, callback:callback )
    }
    
    //
    // MARK: Utility methods
    //
    
    fileprivate func httpPost<N:Mappable,T:BaseResult>(_ path:String, secure:Bool, body:N, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)? = nil, callback:@escaping (T) -> Void) {
        httpUpdate( Method.POST, path:path, secure:secure, body:body, progressHandler:progressHandler, callback:callback )
    }
    
    // Used for POST and PUT
    fileprivate func httpUpdate<N:Mappable,T:BaseResult>(_ method:String, path:String, secure:Bool, body:N, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)? = nil, callback:@escaping (T) -> Void) {
        let json = body is EmptyBody ? nil : Mapper().toJSONString(body, prettyPrint:true)
        httpString(method, path:path, secure:secure, body:json, progressHandler:progressHandler ) {
            (failure,body) -> Void in
            self.processResult(failure: failure, body: body, path: path, callback: callback)
        }
    }
    
    fileprivate func httpFetch<T:BaseResult>(_ method:String, path:String, secure:Bool, callback:@escaping (T) -> Void) {
        httpString(method, path:path, secure:secure, body:nil ) {
            (failure,body) -> Void in
            self.processResult(failure: failure, body: body, path: path, callback: callback)
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
    
    fileprivate func httpString(_ method:String, path:String, secure:Bool, body:String?, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)? = nil, callback:@escaping (Failure?,String?) -> Void ) {
        http(method, path:path, secure:secure, body:body, progressHandler:progressHandler ) {
            failure, data, response in
            
            if failure != nil {
                callback(failure,nil)
            } else {
                let result = NSString(data: data!, encoding:String.Encoding.utf8.rawValue)!
                if MobidoRestClient.DEBUG {
                    print( "MRC Body is \(result)")
                }
                callback(nil,result as String)
            }
        }
    }
    
    fileprivate func http(_ method:String, path:String, secure:Bool, body:String?, progressHandler: ((_ totalSent: Int64, _ uploadSize: Int64) -> Void)? = nil, callback:@escaping (Failure?,Data?,URLResponse?) -> Void ) {
        let accesskey = MyUserDefaults.instance.getAccessKey()
        if accesskey == nil && secure {
            callback(Failure(message: "No access key".localized ),nil,nil)
            return
        }
        
        let host = MyUserDefaults.instance.getMobidoApiServer()
        let url = URL(string:"\(host)/\(MobidoRestClient.apiVersion)\(path)")!
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = method
        //request.addValue("Basic ZHJpbms6Y29rZQ==", forHTTPHeaderField: "Authorization") // drink/coke
        
        var hmac:HMAC?
        if secure {
            var host:String
            let port = (url as NSURL).port
            if port == nil || port == 80 || port == -1 {
                host = url.host!
            } else {
                host = "\(url.host!):\(port!)"
            }
            host = host.lowercased()
            
            let fullpath = "/\(MobidoRestClient.apiVersion)\(path)"
            hmac = HMAC(method:method,fullpath:fullpath,host:host,accesskey:accesskey!)
            request.addValue(hmac!.getDate(), forHTTPHeaderField: "X-Mobido-Date")
        }
        
        if body != nil {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let data: Data = body!.data(using: String.Encoding.utf8)!
            request.httpBody = data
            
            if hmac != nil {
                hmac!.update( data )
            }
        }
        
        if secure {
            request.addValue(hmac!.getAuthorization(), forHTTPHeaderField: "X-Mobido-Authorization")
        }
        
        var progressHandlerEntry:ProgressHandlerEntry?
        if let handler = progressHandler {
            progressHandlerEntry = ProgressHandlerEntry( handler )
        }
        
        let task = urlSession!.dataTask(with: request as URLRequest, completionHandler: {
            data, response, error in
            
            if let phe = progressHandlerEntry {
                self.progressHandlerMap.removeValue(forKey: phe.taskId!)
            }
            
            // networking problem?
            if error != nil {
                let failure = Failure(message: (error?.localizedDescription)!)
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
                let failure = self.parseFailure(url, data:data, response:httpResponse!, error:error )
                callback(failure,nil,nil)
            } else {
                DebugLogger.instance.append( "SUCCESS: \(url)" )
                callback(nil,data,response)
            }
        } ) 
        
        DebugLogger.instance.append( "\(task.taskIdentifier) \(method) \(url)" )
        
        if let phe = progressHandlerEntry {
            phe.taskId = task.taskIdentifier
            progressHandlerMap[ task.taskIdentifier ] = phe
        }
        
        task.resume()
    }
    
    fileprivate func parseFailure(_ url:URL, data:Data?, response:HTTPURLResponse, error:Error?) -> Failure {
        // does the response have the failure as JSON in body?
        if let json = parseJsonBody( data, response:response ) {
            if let failure = json.failure {
                failure.statusCode = response.statusCode
                self.logFailure( failure, url:url )
                return failure;
            }
        }

        // craft a failure from the HTTP fields
        let code = response.statusCode
        let message = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
        let failure = Failure(statusCode:code, message:message)
        self.logFailure( failure, url:url )
        
        return failure
    }
    
    fileprivate func parseJsonBody( _ data:Data?, response:HTTPURLResponse ) -> BaseResult? {
        if let contentType = response.allHeaderFields["Content-Type"] as? String {
            if contentType.hasPrefix( "application/json" ) {
                if let body = NSString(data: data!, encoding:String.Encoding.utf8.rawValue) {
                    let result = Mapper<BaseResult>().map(JSONString:body as String)
                    return result
                }
            }
        }
        
        return nil
    }
    
    fileprivate func logFailure( _ failure:Failure, url:URL ) {
        let code = failure.statusCode == nil ? -1 : failure.statusCode
        DebugLogger.instance.append( "FAILURE: \(String(describing: code)) \(failure.message!) \(url)" )
    }
}
