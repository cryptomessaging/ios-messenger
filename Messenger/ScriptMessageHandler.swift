import Foundation
import WebKit
import ObjectMapper

// NOTE: remember to set restclient when it becomes available
/* NOTE2: Must set javascriptBridge.webview ASAP after init() (the fun of circular references)
class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    
    static let DEBUG = true
    
    weak var botWidget:BotWidget?   // weak to avoid circular reference
    let javascriptBridge = WebviewJavascriptBridge()
    
    // allows bots to interact/callto the Mobido app
    weak var delegate:BotScriptDelegate?
    
    var secureRequests = true    // should we make requests using secure connections
    func resetWidget( widget:BotWidget ) {
        self.botWidget = widget
    }
    
    override init() {
        super.init()
        
        NotificationHelper.addObserver(self, selector: #selector(onChatMessageReceived), name: .chatMessageReceived )
        NotificationHelper.addObserver(self, selector: #selector(onLocationUpdate), name: .locationUpdate )
        
        // When app comes back into foreground, signal view is appearing
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name:NSNotification.Name.UIApplicationWillEnterForeground, object:nil )
    }

    deinit {
        NotificationHelper.removeObserver(self)
    }
    
    func onBackButton() {
        javascriptBridge.invoke( "onBackButton" )
    }
    
    func onLocationUpdate( _ notification:Notification ) {
        if let info = notification.userInfo {
            if let key = info["key"] as? String {
                if key == botWidget?.key {
                    if let lat = toDouble( "lat", info:info ), let lng = toDouble( "lng", info:info ) {
                        let geoloc = Geoloc( lat:lat, lng:lng ).toJSONString()!
                        javascriptBridge.invoke( "onLocation", arg:geoloc )
                    }
                }
            }
        }
    }
    
    fileprivate func toDouble( _ name:String, info:Dictionary<AnyHashable,Any> ) -> Double? {
        if let value = info[name] as? String {
            if let number = Double( value ) {
                return number
            }
        }
        
        return nil
    }

    func onChatMessageReceived( _ notification:Notification ) {
        if let info = notification.userInfo {
            if let msg = info["msg"] as? ChatMessage {
                if msg.tid == botWidget?.tid {    // only pass through messages to this chat thread
                    DebugLogger.instance.append( function: "onIncomingMessage()", preamble:"Incoming chat message to widget", json:msg )
                    javascriptBridge.invoke("onIncomingMessage", param:msg)
                }
            }
        }
    }
    
    /*
    func onThreadUpdated() {
        javascriptBridge.invoke("onThreadUpdated")
    }*/
    
    // Signal view has gone away and is now reappearing
    func willEnterForeground() {
        javascriptBridge.invoke("onViewWillAppear")
    }
    
    fileprivate func convertDictionary<T:Mappable>( _ dict:[String:Any]? ) -> T? {
        guard let dict = dict else {
            return nil
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            if let json = String(data: data, encoding: .utf8) {
                let result = Mapper<T>().map(JSONString:json)!
                return result
            }
        } catch {
            DebugLogger.instance.append( function: "dictionaryTo()", message: "Failed with \(error)" )
        }
        
        return nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
        let body = message.body as? [String:Any]
        let handle = body?["handle"] as? String // matches callback to call
        
        if ScriptMessageHandler.DEBUG {
            print( "script message: \(message.name) handle: \(String(describing: handle))" )
        }
        
        switch message.name {
        case "closeBotWidget":
            delegate?.doCloseBotWidget()
        case "setHeight":
            if let height = body?["height"] as? NSNumber {
                let f = CGFloat(height)
                delegate?.doBotWidgetHeightChange(f)
            }
        case "setCallbackObjectName":
            if let name = body?["name"] as? String {
                javascriptBridge.targetObjectName = name
            }
        case "setOptionItems":
            let optionItems = parseOptionItems( body as AnyObject? )
            delegate?.doSetOptionButtonItems(optionItems)
        case "setBackButton":
            let options = convertDictionary( body ) as BackButtonOptions?
            delegate?.doSetBackButton(options)
        case "setupScreen":
            if let options = convertDictionary( body ) as ScreenOptions? {
                delegate?.doSetupScreen(options)
            }
        case "fetchEnvironment":
            var env = WidgetEnvironment()
            env.version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String
            let prefs = MyUserDefaults.instance
            env.debug = prefs.check(.IsWidgetDeveloper)
            env.tz = TimeZone.autoupdatingCurrent.identifier
            env.theme = prefs.getTheme().lowercased()
            
            delegate?.doEnvironmentFixup(&env)
            
            let json = env.toJSONString()!
            javascriptBridge.invoke( "onEnvironment", arg:json )
        
        // calendar
        case "fetchFreeBusy":
            // get free/busy information from calendar for the next N days
            let startDay = body?["startDay"] as? NSNumber    // 0=today, 1=tomorrow
            let endDay = body?["endDay"] as? NSNumber        // must be >= startDay
            let dates = CalendarService.toDates( startDay == nil ? 0 : startDay!.intValue, endDay:endDay == nil ? 14 : endDay!.intValue )
            
            CalendarService.instance.fetchFreeBusy( dates.startDate, endDate:dates.endDate ) {
                access, schedule in
                if let schedule = schedule {
                    //let json = schedule.toJSONString()!
                    self.javascriptBridge.invoke("onFreeBusy", handle:access.rawValue, param:schedule)
                    AnalyticsHelper.trackActivity(.widgetFreeBusyDip, value: self.botWidget?.restClient?.botcid )
                }
            }
        case "requestFreeBusyUpdates":
            // request offline monitoring of free/busy and send updates to bot server
            let hook = body?["webhook"] as? String

            // get free/busy information from calendar for the next N days
            let startDay = body?["startDay"] as? NSNumber    // 0=today, 1=tomorrow
            let endDay = body?["endDay"] as? NSNumber        // must be >= startDay
            let dates = CalendarService.toDates( startDay == nil ? 0 : startDay!.intValue, endDay:endDay == nil ? 14 : endDay!.intValue )
            
            guard let webhook = hook, let mycid = botWidget?.mycid, let tid = botWidget?.tid else {
                print( "ERROR: Cannot request free/busy updates since mycid or botcid is missing")
                return
            }
            
            CalendarService.instance.requestFreeBusyUpdates( dates.startDate, endDate:dates.endDate, webhook:webhook, tid:tid, mycid:mycid, botcid:botcid() ) {
                access in
                let json = "'\(access.rawValue)'"
                self.javascriptBridge.invoke( "onFreeBusyRequest", arg:json )
            }
        case "cancelFreeBusyUpdates":
            if let mycid = botWidget?.mycid, let tid = botWidget?.tid {
                CalendarService.instance.cancelFreeBusyUpdates( tid, mycid:mycid, botcid:botcid() )
            } else {
                print( "ERROR: Cannot cancel free/busy updates since mycid or botcid is missing")
            }
            
        // location
        case "fetchLocation":
            // get location for local use ONLY - DO NOT BROADCAST!
            if let locationUpdateHandler = botWidget?.locationUpdateHandler {
                LocationService.instance.fetchLocation(locationUpdateHandler)
            }
        case "sendLocation":
            // get location once, but also broadcast back to bot server
            if let locationUpdateHandler = botWidget?.locationUpdateHandler {
                locationUpdateHandler.broadcastOnce = true
                LocationService.instance.fetchLocation(locationUpdateHandler)
            }
        case "requestLocationUpdates":
            if let minutes = body?["minutes"] as? NSNumber, let locationUpdateHandler = botWidget?.locationUpdateHandler {
                LocationService.instance.requestLocationUpdates( locationUpdateHandler, minutes:Int(minutes) )
                AnalyticsHelper.trackResult(.widgetLocationOn, value:botcid() )
            }
        case "cancelLocationUpdates":
            if let locationUpdateHandler = botWidget?.locationUpdateHandler {
                LocationService.instance.cancelLocationUpdates(locationUpdateHandler)
                AnalyticsHelper.trackResult(.widgetLocationOff, value:botcid())
            }
        
        // thread info, history
        case "fetchThreadList":
            if let tids = body?["tids"] as? [String] {
                if let result = delegate?.fetchThreadList( tids ) {
                    javascriptBridge.invoke("onThreadList", param:result)
                }
            }
        case "fetchThread":
            if let thread = delegate?.fetchThread() {
                javascriptBridge.invoke("onThread", param:thread)
            }
        case "fetchMessageHistory":
            if let messages = delegate?.fetchMessageHistory() {
                javascriptBridge.invoke("onMessageHistory",handle:handle, param:messages)
            }
            
        // get cards
        case "fetchThreadCards":
            if let cards = delegate?.fetchThreadCards() {
                javascriptBridge.invoke("onThreadCards", param:cards)
            }
        case "fetchUserCard":
            if let card = delegate?.fetchUserCard() {
                javascriptBridge.invoke("onUserCard", param:card)
            }
        case "fetchBotCard":
            if let card = delegate?.fetchBotCard() {
                javascriptBridge.invoke("onBotCard", param:card)
            }
            
        case "selectUserCard":
            let options = convertDictionary( body ) as SelectUserCardOptions?
            delegate?.doSelectUserCard( options:options ) {
                failure, card in
                self.javascriptBridge.invoke( "onUserCardSelected", failure: failure, param: card )
            }
            
        case "ensureExclusiveChat":
            let subject = body?["subject"] as? String
            let updateRestClient = body?["updateRestClient"] as? Bool
            let r = updateRestClient != nil && updateRestClient!
            delegate?.doEnsureExclusiveChat( subject:subject, updateRestClient:r ) {
                failure, thread in
                self.javascriptBridge.invoke( "onExclusiveChat", failure: failure, param: thread )
            }
            
        case "showChat":
            if let options = convertDictionary( body ) as ShowChatOptions? {
                delegate?.doShowChat(options)
            }
            

        // Call HTTP/REST endpoint on bot server using Diffie-Hellman and HTTPS
            
        // GET from endpoint, consuming a JSON response
        case "queryBotServerJson":
            if let path = body?["path"] as? String {
                if ScriptMessageHandler.DEBUG { print( "queryBotServerJson \(path) handle \(String(describing: handle))" ) }
                
                if let baseUrl = botWidget?.restClient?.baseUrl?.absoluteString, let handle = handle {
                    AnalyticsHelper.trackActivity( .queryBotServer, source:baseUrl, value:handle )
                }
                botWidget?.restClient?.httpString(BotRestClient.Method.GET, path:path, secure:self.secureRequests, content:nil, contentType:nil ) {
                    failure, json in
                    if let failure = failure {
                        DebugLogger.instance.append(function:"queryBotServerJson:failure", failure:failure )
                        self.javascriptBridge.invoke("onBotServerErrorResponse", handle:handle, param:failure )
                    } else if let json = json {
                        let trimmed = json.truncate(length:100)
                        if ScriptMessageHandler.DEBUG { print( "queryBotServerJson response \(path) handle \(String(describing: handle)) json \(trimmed)" ) }
                        self.javascriptBridge.invoke("onBotServerJsonResponse", handle:handle, arg:json)
                    }
                }
            }
            
        // POST, PUT, DELETE, etc. an endpoint with data of the specified content type, response is JSON
        case "updateBotServer":
            let method = body?["method"] as! String
            let content = body?["content"] as? String
            let contentType = body?["contentType"] as? String
            if let path = body?["path"] as? String {
                if ScriptMessageHandler.DEBUG { print( "updateBotServer \(method) \(path) content \(String(describing: content)) contentType \(String(describing: contentType)) handle \(String(describing: handle))" ) }
                if let baseUrl = botWidget?.restClient?.baseUrl?.absoluteString, let handle = handle {
                    AnalyticsHelper.trackActivity( .updateBotServer, source:baseUrl, value:handle )
                }
                botWidget?.restClient?.httpString(method, path:path, secure:self.secureRequests, content:content, contentType:contentType ) {
                    failure, json in
                    if let failure = failure {
                        //ProblemHelper.showProblemOnMainThread(nil, title: "Failed to connect to bot server", failure: failure)
                        self.javascriptBridge.invoke("onBotServerErrorResponse", handle:handle, param:failure )
                    } else if let json = json {
                        let trimmed = json.truncate(length:100)
                        if ScriptMessageHandler.DEBUG { print( "updateBotServer response \(path) handle \(String(describing: handle)) json \(trimmed)" ) }
                        self.javascriptBridge.invoke("onBotServerJsonResponse", handle:handle, arg:json)
                        //AnalyticsHelper.trackResult(.WidgetUpdated, value: self.botcid() )
                    }
                }
            }
            
        default:
            DebugLogger.instance.append( function: "onIncomingMessage()", message: "Unknown message type \(message.name) in \(message)" )
        }
    }
    
    fileprivate func botcid() -> String {
        return botWidget!.botCard.cid!
    }
    
    // Ugh, WKScriptMessage wants to decode the nice JSON into a dictionary graph...
    fileprivate func parseOptionItems( _ body:AnyObject? ) -> [OptionItem] {
        var result:[OptionItem] = []
        if let dic = body as? Dictionary<String, AnyObject> {
            if let items = dic["items"] as? Array<Dictionary<String,AnyObject>> {
                for i in items {
                    let oi = OptionItem()
                    oi.label = i["label"] as? String
                    oi.id = i["id"] as? String
                    oi.url = i["url"] as? String
                    
                    result.append( oi )
                }
            }
        }

        return result
    }
    
    // tell the bot an option item was tapped
    func onOptionItemSelected(_ id:String) {
        javascriptBridge.invoke("onOptionItemSelected",arg: "'\(id)'")
    }
    
    func addHandlers(_ ucc:WKUserContentController) {
        ucc.add( self, name: "setCallbackObjectName" )
        ucc.add( self, name: "setHeight" )
        ucc.add( self, name: "setOptionItems" )
        ucc.add( self, name: "setBackButton" )
        ucc.add( self, name: "setupScreen" )
        ucc.add( self, name: "fetchEnvironment" )
        
        ucc.add( self, name: "closeBotWidget" )
        
        ucc.add( self, name: "fetchFreeBusy" )
        ucc.add( self, name: "requestFreeBusyUpdates" )    // ask for updates/changes to be sent to bot server
        ucc.add( self, name: "cancelFreeBusyUpdates" )    // ask for updates/changes to be sent to bot server
        
        ucc.add( self, name: "fetchLocation" )
        ucc.add( self, name: "sendLocation" )
        ucc.add( self, name: "requestLocationUpdates" )
        ucc.add( self, name: "cancelLocationUpdates" )
      
        ucc.add( self, name: "fetchThread" )
        ucc.add( self, name: "fetchThreadList" )
        ucc.add( self, name: "fetchMessageHistory" )
        
        ucc.add( self, name: "fetchThreadCards" )
        ucc.add( self, name: "fetchUserCard" )
        ucc.add( self, name: "selectUserCard" )
        ucc.add( self, name: "fetchBotCard" )

        ucc.add( self, name: "queryBotServerJson" )
        ucc.add( self, name: "updateBotServer" )
        
        ucc.add( self, name: "ensureExclusiveChat" )
        ucc.add( self, name: "showChat" )
    }
}

// Invokes/executes methods on a target Javascript object in the webview
class WebviewJavascriptBridge {
    var targetObjectName:String?
    weak var webview:WKWebView?
    
    fileprivate func invoke(_ function:String) {
        if let name = targetObjectName {
            let js = "\(name).\(function)()"
            DispatchQueue.main.async {
                self.webview?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    // call back into the web page
    fileprivate func invoke<N:Mappable>(_ function:String, handle:String?, param:N) {
        let arg = param.toJSONString() ?? "null"
        invoke(function, handle:handle, arg:arg )
    }
    
    fileprivate func invoke<N:Mappable>(_ function:String, handle:String?, param:[N]) {
        let arg = param.toJSONString() ?? "null"
        invoke(function, handle:handle, arg:arg )
    }
    
    fileprivate func invoke(_ function:String, handle:String?, arg:String) {
        let h = handle != nil ? "'\(handle!)'" : "null"
        if let name = targetObjectName {
            let js = "\(name).\(function)(\(h),\(arg))"
            DispatchQueue.main.async {
                self.webview?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }
    
    fileprivate func invoke<N:Mappable>(_ function:String, param:N) {
        let arg = param.toJSONString() ?? ""
        self.invoke( function, arg:arg )
    }
    
    fileprivate func invoke<N:Mappable>(_ function:String, param:[N]) {
        let arg = param.toJSONString() ?? ""
        invoke( function, arg:arg )
    }
    
    fileprivate func invoke(_ function:String, arg:String) {
        if let name = targetObjectName {
            let js = "\(name).\(function)(\(arg))"
            DispatchQueue.main.async {
                self.webview?.evaluateJavaScript(js)
            }
        }
    }
    
    fileprivate func invoke<N:Mappable>(_ function:String, failure:Failure?, param:N?) {
        let err = failure?.toJSONString() ?? "null"
        let arg = param?.toJSONString() ?? "null"
        
        if let name = targetObjectName {
            let js = "\(name).\(function)(\(err),\(arg))"
            DispatchQueue.main.async {
                self.webview?.evaluateJavaScript(js)
            }
        }
    }
}
 */
