import Foundation
import UIKit
import WebKit

class ResetContext {
    var mycid:String?
    var tid:String?
    var botCard:Card!
    let bridge = BotScriptBridge()
}

// A rectangular screen area for a bot to present graphical information
// and interact with the user.  This container is fixed, and different bots can be swapped
// in and out
class BotWidgetView: UIView {
    
    fileprivate let leftBorder = CALayer()
    
    // these are changed in each reset()
    fileprivate var botScriptBridge:BotScriptBridge?
    fileprivate var webview:WKWebView!
    fileprivate var layoutConstraints:[NSLayoutConstraint]?
    weak var delegate:BotScriptDelegate?
    weak var vc:UIViewController? {
        didSet {
            optionButton.vc = vc
        }
    }
    let optionButton = BotOptionButton()
    fileprivate var isSimpleTheme = false

    var botCard:Card? {
        get {
            //return botWidget?.botCard
            return botScriptBridge?.botCard
        }
    }

    //
    // MARK: Initial set up
    //
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame:frame )
        commonInit()
    }
    
    fileprivate func commonInit() {
        isSimpleTheme = MyUserDefaults.instance.getTheme() == ThemeHelper.ThemeType.SIMPLE.rawValue
        autoresizingMask = UIViewAutoresizing()
        translatesAutoresizingMaskIntoConstraints = false
        if !isSimpleTheme {
            layer.addSublayer( leftBorder )
        }
        
        addSubview( optionButton )
    }
    
    //
    // MARK: Reset for new bot
    //
    
    func reset() {
        if let constraints = layoutConstraints {
            for c in constraints {
                self.removeConstraint( c )
            }
            self.layoutConstraints = nil
        }

        webview?.removeFromSuperview()
        botScriptBridge = nil
    }

    // always run on main thread!
    func reset( _ tid:String, mycid:String?, botCard:Card, color:UIColor ) {
        reset()
        reset( color )
        optionButton.items = nil
        
        let resetContext = ResetContext()
        resetContext.tid = tid
        resetContext.mycid = mycid
        resetContext.botCard = botCard
        resetContext.bridge.delegate = self.delegate
        
        if let delegate = delegate {
            optionButton.setup( parentView:self, bridge:resetContext.bridge, delegate:delegate )
        } else {
            DebugLogger.instance.append( "ERROR: Failed to find bot script delegate to setup option button" )
        }
        
        // webview
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = BotHelper.createUserContentController()!
        self.webview = WKWebView(frame: frame, configuration: webViewConfig )
        webview.autoresizingMask = UIViewAutoresizing()
        webview.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview( webview )
        resetContext.bridge.webview = webview   // wires in webview JS handlers here
        
        setConstraints()
        
        // make sure the options button is always in view
        self.bringSubview( toFront: optionButton )
        
        // They might be waiting... give 'em a spinner
        let progress = SimpleProgressIndicator(parent: self, message: "Loading widget".localized )
        
        // get the bot metadata/manifest
        self.botScriptBridge = resetContext.bridge
        BotHelper.loadMetapage( botCard ) {
            metapage, url in
         
            if let failure = metapage.failure {
                ProblemHelper.showProblem( nil, title: "Problem with Bot".localized, failure: failure )
                progress.stop()
            } else {
                self.resetContinued2( resetContext, metapage:metapage, progress:progress )
            }
        }
    }
    
    func reset(_ color:UIColor) {
        if isSimpleTheme != true {
            leftBorder.backgroundColor = color.cgColor
            optionButton.circleLayer.fillColor = color.cgColor
        }
    }
    
    // pin webview to sides, top, and bottom of this view
    fileprivate func setConstraints() {
        let topConstraint = NSLayoutConstraint(item: webview, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 0)
        addConstraint( topConstraint )
        
        let bottomConstraint = NSLayoutConstraint(item: webview, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0)
        addConstraint( bottomConstraint )
        
        let leftBorderWidth = isSimpleTheme ? 0 : UIConstants.LeftBorderWidth
        let leadingConstraint = NSLayoutConstraint(item: webview, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: leftBorderWidth ) // leave space for bot indicator color bar
        addConstraint( leadingConstraint )
        
        let trailingConstraint = NSLayoutConstraint(item: webview, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: 0)
        addConstraint( trailingConstraint )
        
        self.layoutConstraints = [ topConstraint, bottomConstraint, leadingConstraint, trailingConstraint ]
    }
    
    // if we have a cid, then get my private key for secure communications
    fileprivate func resetContinued2(_ resetContext:ResetContext, metapage:MetapageResult, progress:SimpleProgressIndicator ) {
        if resetContext.bridge != self.botScriptBridge {
            // another has taken its place, so give up
            progress.stop()
            return
        }
        
        if let mycid = resetContext.mycid {
            CardHelper.loadMyPrivateKey( mycid, type:Crypto.Types.MODP15 ) {
                failure, privateKey in
                
                if failure != nil {
                    ProblemHelper.showProblem( nil, title: "Failed to get your private key".localized, failure: failure! )
                    progress.stop()
                } else {
                    self.resetContinued3( resetContext, metapage:metapage, privateKey:privateKey, progress:progress )
                }
            }
        } else {
            resetContinued3( resetContext, metapage:metapage, privateKey:nil, progress:progress )
        }
    }
    
    fileprivate func resetContinued3(_ resetContext:ResetContext, metapage:MetapageResult, privateKey:Crypto?, progress:SimpleProgressIndicator ) {
        if resetContext.bridge != self.botScriptBridge {
            // another has taken its place, so give up
            progress.stop()
            return
        }
        
        resetContext.bridge.reset( mycid: resetContext.mycid, privateKey:privateKey, tid:resetContext.tid, botCard:resetContext.botCard, metapage:metapage )
        
        // and finally... load the widget HTML, if any
        guard let url = metapage.widget?.url else {
            let title = resetContext.botCard?.nickname
            if let webview = self.webview {
                DispatchQueue.main.async {
                    webview.loadHTMLString("<html><body>\(title!)</body></html>", baseURL: nil)
                }
            }
            progress.stop()
            return
        }
        
        let secure = false; // TODO, load securely?
        botScriptBridge?.restClient?.fetchHTML( url, secure:secure ) {
            failure, html in
            
            if resetContext.bridge != self.botScriptBridge {
                // another has taken its place, so give up
                progress.stop()
                return
            }
            
            if let failure = failure {
                ProblemHelper.showProblem( nil, title: "Failed to get widget HTML".localized, failure: failure )
                progress.stop()
            } else if let webview = self.webview {
                DispatchQueue.main.async {
                    webview.loadHTMLString( html!, baseURL: resetContext.bridge.restClient!.baseUrl )
                    self.trackPageLoading( progress, webview:webview )
                }
            } else {
                print( "This should never happen, webview is nil?!")
                progress.stop()
            }
        }
    }
    
    fileprivate func trackPageLoading( _ progress:SimpleProgressIndicator, webview:WKWebView ) {
        UIHelper.delay( 0.1 ) {
            if webview.window == nil {
                progress.stop()
            } else if webview.estimatedProgress == 1.0 {
                if let bridge = self.botScriptBridge, let nickname = bridge.botCard?.nickname {
                    AnalyticsHelper.trackScreenElement( .widget, value: nickname )
                }
                progress.stop()
            } else {
                // try again
                self.trackPageLoading( progress, webview:webview )
            }
        }
    }
    
    //
    // MARK: Color left border so we know which bot is presenting
    //
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        leftBorder.frame = CGRect(x: 0,y: 0,width: UIConstants.LeftBorderWidth,height: frame.height)
    }
}
