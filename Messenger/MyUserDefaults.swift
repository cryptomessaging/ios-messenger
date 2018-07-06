import Foundation
import ObjectMapper

class DefaultThreadWidget: Mappable {
    
    var cid: String?
    var lastUsed: Double?
    
    init() {
    }
    
    required init?(map: Map) {
    }
    
    func mapping(map: Map) {
        cid <- map["cid"]
        lastUsed <- map["lastUsed"]
    }
}

class MyUserDefaults {
    
    enum BooleanKey: String {
        case IsWidgetDeveloper
        case IsLocationDeveloper
        case IsLogging
        case WasQuickstartOffered
        //case ChatTextInputAutocorrection
        case DisableChatTextAutocorrection
    }
    
    enum StringKey: String {
        case SIGNUP_BIRTHDAY
        case SIGNUP_KIDNAME
        case SIGNUP_PARENT_EMAIL
        //case SIGNUP_STATUS
        case THEME
        case SOUND_SETTING
        
        case BOT_PROXY_PATTERN
        case BOT_PROXY_REPLACEMENT
        case PENDING_RSVP_SECRET
        
        case MARKET_PASSCODE
        
        case HOMEPAGE_MANAGER_CID           // bot or user running homepage
        case HOMEPAGE_DEFAULT_USER_CID      // card selected by user as default
    }
    
    static let instance = MyUserDefaults()
    fileprivate let defaults = UserDefaults.standard
    
    struct Key {
        static let MOBIDO_API_SERVER = "mobido_api_server"
        
        // auth values
        static let LOGIN_ID = "login_id"
        static let ACCESS_KEY_ID = "access_key_id"
        static let ACCESS_KEY_SECRET = "access_key_secret"
        static let ACCESS_KEY_ACM = "access_key_acm"
        
        static let DEFAULT_CARD_ID = "default_card_id"
        static let CARD_PRIVATE_KEY_PREFIX = "card_private_key/"
        
        // developer
        static let WIDGET_DEVELOPER = "widget_developer"
        
        // time for next full thread sync, epoch seconds as Double
        static let NEXT_FULL_THREAD_SYNC = "next_full_thread_sync"
        
        static let DEFAULT_THREAD_WIDGETS = "default_thread_widgets";
        
        static let SIGNUP_BIRTHDAY = "signup_birthday";
        static let SIGNUP_KIDNAME = "signup_kidname";
        static let SIGNUP_PARENT_EMAIL = "signup_parent_email";
        static let SIGNUP_STATUS = "signup_status";
    }
    
    static let DEFAULT_MOBIDO_API_SERVER = "https://m.mobido.com"
    
    fileprivate init() {
    }
    
    func clear( exceptAuth:Bool, exceptLoginId:Bool ) {
        let apiServer = defaults.string(forKey: Key.MOBIDO_API_SERVER)
        let isLogging = check( .IsLogging )
        let loginId = getLoginId()
        let accessKey = getAccessKey()
        
        let passcode = get( .MARKET_PASSCODE )
        let proxyPattern = get( .BOT_PROXY_PATTERN )
        let proxyReplacement = get( .BOT_PROXY_REPLACEMENT )
        
        defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        if exceptAuth {
            setAccessKey(accessKey)
            set( .MARKET_PASSCODE, withValue: passcode )
        }
        
        if exceptLoginId {
            setLoginId(loginId)
        }
        
        if let url = apiServer {
            setMobidoAPIServer(url)
            set( .BOT_PROXY_PATTERN, withValue: proxyPattern )
            set( .BOT_PROXY_REPLACEMENT, withValue: proxyReplacement )
        }
        set( .IsLogging, value:isLogging )
    }
    
    //
    // MARK: Accessors
    //
    
    fileprivate var defaultWidgetsCache:[String:String]?
    
    func setDefaultWidget(_ cid:String?, forThread:String) {
        if defaultWidgetsCache == nil {
            defaultWidgetsCache = defaults.dictionary( forKey: Key.DEFAULT_THREAD_WIDGETS ) as? [String:String]
            if defaultWidgetsCache == nil {
                defaultWidgetsCache = [String:String]()
            }
            
            // TODO periodically clean out old entries
        }
        
        let entry = DefaultThreadWidget()
        entry.cid = cid
        entry.lastUsed = CFAbsoluteTimeGetCurrent()
            
        let json = Mapper().toJSONString(entry)
        defaultWidgetsCache![forThread] = json
            
        defaults.set(defaultWidgetsCache, forKey: Key.DEFAULT_THREAD_WIDGETS)
    }

    func getDefaultWidget(_ forThread:String) -> String? {
        if defaultWidgetsCache == nil {
            defaultWidgetsCache = defaults.dictionary( forKey: Key.DEFAULT_THREAD_WIDGETS ) as? [String:String]
            if defaultWidgetsCache == nil {
                defaultWidgetsCache = [String:String]()
                return nil
            }
            
            // TODO periodically clean out old entries
        }
        
        if let json = defaultWidgetsCache![forThread] {
            let entry = Mapper<DefaultThreadWidget>().map( JSONString:json )!
            
            // update entry time "last touched"
            entry.lastUsed = CFAbsoluteTimeGetCurrent()
            let json = Mapper().toJSONString(entry)
            
            // and save to local memory and permanent caches
            defaultWidgetsCache![forThread] = json
            defaults.set(defaultWidgetsCache, forKey: Key.DEFAULT_THREAD_WIDGETS)
            
            return entry.cid
        } else {
            // no default widget for this thread
            return nil
        }
    }
    
    func removeDefaultWidget(_ fromThread:String) {
        if defaultWidgetsCache == nil {
            defaultWidgetsCache = defaults.dictionary( forKey: Key.DEFAULT_THREAD_WIDGETS ) as? [String:String]
            if defaultWidgetsCache == nil {
                defaultWidgetsCache = [String:String]()
                return
            }
        }
        
        defaultWidgetsCache!.removeValue(forKey: fromThread)
        defaults.set(defaultWidgetsCache, forKey: Key.DEFAULT_THREAD_WIDGETS)
    }
    
    func setCardPrivateKey( _ cid:String, privateKey:Crypto ) {
        let key = privateKeyKey( cid, type:privateKey.type! )
        let json = Mapper().toJSONString(privateKey)
        setString( json, key: key )
    }
    
    func getCardPrivateKey( _ cid:String, type:String ) -> Crypto? {
        let key = privateKeyKey( cid, type:type )
        if let json = defaults.string( forKey: key ) {
            return Mapper<Crypto>().map( JSONString:json )
        } else {
            return nil
        }
    }
    
    fileprivate func privateKeyKey( _ cid:String, type:String ) -> String {
        return Key.CARD_PRIVATE_KEY_PREFIX + cid + "/" + type
    }
    
    func setMobidoAPIServer(_ url:String?) {
        setString(url,key: Key.MOBIDO_API_SERVER)
    }
    
    func getMobidoApiServer() -> String {
        if let host = defaults.string(forKey: Key.MOBIDO_API_SERVER) {
            return host
        } else {
            return MyUserDefaults.DEFAULT_MOBIDO_API_SERVER
        }
    }
    
    func isDefaultMobidoApiServer() -> Bool {
        let apiServer = getMobidoApiServer()
        let defaultServer = MyUserDefaults.DEFAULT_MOBIDO_API_SERVER
        if defaultServer == apiServer { return true }
        
        // handle user typing http://www.mobido.com/  (NOTE trailing slash)
        if apiServer.hasPrefix( defaultServer ) &&
            defaultServer.characters.count == apiServer.characters.count - 1 &&
            apiServer.characters.last == "/" { return true }
        
        return false
    }
    
    func setLoginId(_ id:String?) {
        setString(id, key: Key.LOGIN_ID)
    }
    
    func getLoginId() -> String? {
        return defaults.string(forKey: Key.LOGIN_ID)
    }
    
    func setDefaultCardId(_ id:String?) {
        setString(id, key: Key.DEFAULT_CARD_ID)
    }
    
    func getDefaultCardId() -> String? {
        return defaults.string(forKey: Key.DEFAULT_CARD_ID)
    }
    
    func setNextFullThreadSync( _ time:Double ) {
        defaults.set(time, forKey: Key.NEXT_FULL_THREAD_SYNC )
    }
    
    func getNextFullThreadSync() -> Double {
        return defaults.double( forKey: Key.NEXT_FULL_THREAD_SYNC )
    }
    
    func setAccessKey(_ key:AccessKey?) {
        if key == nil {
            defaults.removeObject(forKey: Key.ACCESS_KEY_ID)
            defaults.removeObject(forKey: Key.ACCESS_KEY_SECRET)
            defaults.removeObject(forKey: Key.ACCESS_KEY_ACM)
        } else {
            defaults.set(key?.id, forKey: Key.ACCESS_KEY_ID)
            defaults.set(key?.secret, forKey: Key.ACCESS_KEY_SECRET)
            defaults.set(key?.acm, forKey: Key.ACCESS_KEY_ACM)
        }
    }
    
    func getAccessKey() -> AccessKey? {
        let id = defaults.string(forKey: Key.ACCESS_KEY_ID)
        let secret = defaults.string(forKey: Key.ACCESS_KEY_SECRET)
        let acm = defaults.dictionary(forKey: Key.ACCESS_KEY_ACM) as? [String:String]
        return AccessKey(id:id,secret:secret,acm:acm)
    }
    
    func getTheme() -> String {
        if let theme = get(.THEME) {
            return theme
        } else {
            return ThemeHelper.ThemeType.SIMPLE.rawValue
        }
    }
    
    func setTheme( _ theme:String ) {
        set( .THEME, withValue: theme )
    }
    
    func getSoundSetting() -> String {
        if let sounds = get(.SOUND_SETTING) {
            return sounds
        } else {
            return SoundHelper.Setting.ALWAYS_ON.rawValue
        }
    }
    
    func setSoundSetting( _ theme:String ) {
        set( .SOUND_SETTING, withValue: theme )
    }
    
    func check(_ key:BooleanKey) -> Bool {
        return defaults.bool( forKey: key.rawValue )
    }
    
    func set( _ key:BooleanKey, value:Bool ) {
        defaults.set(value, forKey: key.rawValue )
        
        if key == .IsLogging {
            DebugLogger.instance.logging = value
        }
    }
    
    func set( _ key:StringKey, withValue value:String? ) {
        if let value = value {
            defaults.set(value, forKey: key.rawValue )
        } else {
            defaults.removeObject( forKey: key.rawValue )
        }
    }
    
    func get(_ key:StringKey) -> String? {
        return defaults.string(forKey: key.rawValue)
    }
    
    //
    // MARK: Utility
    //
    
    fileprivate func setString(_ value:String?, key:String ) {
        if let value = value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
