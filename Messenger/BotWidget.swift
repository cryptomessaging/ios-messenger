import Foundation
import UIKit
import WebKit

/*
class BotWidget: NSObject {
    // these are always known right away, and dont change
    fileprivate(set) var tid:String?
    fileprivate(set) var mycid:String?   // ok to be nil
    fileprivate(set) var botCard:Card
    let key:String
    
    // fun circular reference: webview -> config -> scriptMessageHandler -> webview, so it's weak here
    weak var webview:WKWebView? {
        didSet {
            // allow javascript bridge to affect webview
            scriptMessageHandler.javascriptBridge.webview = webview
        }
    }
    
    // I manage these
    var scriptMessageHandler:ScriptMessageHandler!
    let locationUpdateHandler:LocationListener!
    
    // _might_ fail coming in, or be delayed
    var metapage:MetapageResult?
    var restClient:BotRestClient?
    
    init( tid:String?, mycid:String?, botCard:Card, scriptMessageHandler:ScriptMessageHandler? = nil ) {
        self.tid = tid
        self.mycid = mycid
        self.botCard = botCard
        self.key = BotWidget.keyFor( tid:tid, mycid:mycid, botcid:botCard.cid! )
        self.scriptMessageHandler = scriptMessageHandler != nil ? scriptMessageHandler! : ScriptMessageHandler()
        self.locationUpdateHandler = LocationListener( key:key )
        super.init()

        LocationService.instance.registerListener( locationUpdateHandler, requirePrevious: true, completion: nil )        
        scriptMessageHandler!.botWidget = self
    }
    
    class func keyFor( tid:String?, mycid:String?, botcid:String ) -> String {
        return "tid(\(tid == nil ? "?" : tid!))mycid(\(mycid == nil ? "?" : mycid!))botcid(\(botcid))"
    }
    
    func dupe() -> BotWidget {
        let dupe = BotWidget( tid:self.tid, mycid:self.mycid, botCard:self.botCard)
        dupe.metapage = metapage
        dupe.restClient = restClient
        return dupe
    }
    
    // optionals
    var layoutConstraints:[NSLayoutConstraint]?
}
 */
