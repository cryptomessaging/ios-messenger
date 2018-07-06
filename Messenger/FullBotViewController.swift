import UIKit
import WebKit

class FullBotViewController : UIViewController, BotScriptDelegate {
    
    var printButton:UIBarButtonItem!
    fileprivate var botScriptBridge:BotScriptBridge!
    fileprivate var botScriptDelegate:BotScriptDelegate?
    fileprivate var webview:WKWebView!
    var mytitle:String!
    var url:String!
    
    fileprivate let optionButton = BotOptionButton()
    
    class func showBotView( _ nav:UINavigationController, url:String, title:String, bridge:BotScriptBridge, delegate:BotScriptDelegate ) {
        
        let botvc = FullBotViewController()
        botvc.url = url
        botvc.mytitle = title
        botvc.botScriptBridge = bridge.dupe()
        botvc.botScriptDelegate = delegate  // keep track of caller
        
        nav.pushViewController(botvc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        botScriptBridge.delegate = self
        
        //===== Wire in WKWebView =====
        
        let webViewConfig = WKWebViewConfiguration()
        webViewConfig.userContentController = BotHelper.createUserContentController()!
        let webview = WKWebView(frame: view.frame, configuration: webViewConfig )
        webview.autoresizingMask = UIViewAutoresizing()
        webview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview( webview )
        
        botScriptBridge.webview = webview
        
        //===== Add navigation =====
        
        // left back button
        //let leftButton = UIBarButtonItem(title: "Back".localized, style: UIBarButtonItemStyle.plain, target: self, action:#selector(leftButtonAction) )
        //navigationItem.leftBarButtonItem = leftButton
        
        // right print button
        printButton = UIBarButtonItem(title: "Print".localized, style: UIBarButtonItemStyle.plain, target: self, action:#selector(printCurrentPage) )
        navigationItem.rightBarButtonItem = printButton
        
        self.title = mytitle
        
        //===== Load web content =====

        let secure = false; // TODO, load securely?
        botScriptBridge.restClient?.fetchHTML( url, secure:secure ) {
            failure, html in
            
            if let failure = failure {
                ProblemHelper.showProblem( nil, title: "Failed to get widget HTML".localized, failure: failure )
            } else {
                DispatchQueue.main.async {
                    _ = webview.loadHTMLString( html!, baseURL: self.botScriptBridge.restClient!.baseUrl )
                }
            }
        }

        let yoffset = UIApplication.shared.statusBarFrame.height + UIHelper.navigationBarHeight(self)
        optionButton.vc = self
        optionButton.setup( parentView:self.view, bridge:botScriptBridge, delegate:botScriptDelegate!, yoffset:yoffset )

        view.addSubview( optionButton )
        view.bringSubview( toFront: optionButton )
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .fullWidget, vc:self )
    }
    
    func leftButtonAction( _ sender: UIBarButtonItem ) {
        //UIHelper.unwind( vc:self )
        self.navigationController?.popViewController(animated: true)
    }
    
    func printCurrentPage() {
        let printController = UIPrintInteractionController.shared
        let printFormatter = botScriptBridge.webview!.viewPrintFormatter()
        printController.printFormatter = printFormatter
        
        let completionHandler: UIPrintInteractionCompletionHandler = { (printController, completed, error) in
            if !completed {
                if let e = error {
                    DebugLogger.instance.append( function:"printCurrentPage()", error:e )
                } else {
                    print("[PRINT] Canceled" )
                }
            }
        }
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            printController.present(from: self.printButton, animated: true, completionHandler: completionHandler)
        } else {
            printController.present(animated: true, completionHandler: completionHandler)
        }
    }
    
    //===== Bot Script Delegate =====
    
    func doSetBackButton( _ options:BackButtonOptions? ) {
        // ignored TBD
    }
    
    func doSetupScreen( _ options:ScreenOptions ) {
        // ignored TBD
    }
    
    func doCloseBotWidget() {
        UIHelper.unwind( vc:self )
    }
    
    func doBotWidgetHeightChange(_ height:CGFloat) {
        // ignored
    }
    
    func doSelectUserCard( options:SelectUserCardOptions?, completion:@escaping( _ failure:Failure?, _ card:Card?) -> Void ) -> Void {
        if let card = fetchUserCard() {
            completion(nil,card)
        } else {
            completion( Failure( message: "You are not in this chat, so no persona is available (Error)".localized ), nil )
        }
    }
    
    func doEnsureExclusiveChat( subject:String?, updateRestClient:Bool, _ completion:@escaping( _ failure:Failure?, _ thread:ChatThread?) -> Void ) -> Void {
        if updateRestClient {
            let message = String( format:"Requested option '%@' is not available (Error)".localized, "updateRestClient" )
            completion( Failure( message:message ), nil )
            return
        }
        
        if let userCard = fetchUserCard(), let botCard = fetchBotCard() {
            ExclusiveChatHelper.ensureExclusiveChat( parent: self.view, mycard:userCard, peer:botCard, subject:subject, completion:completion )
        } else {
            completion( Failure( message: "Your persona must be selected first (Error)".localized ), nil )
        }
    }
    
    func doShowChat( _ options:ShowChatOptions ) {
        if let tid = options.tid {
            NotificationHelper.signalShowChat( tid );
        }
    }
    
    func fetchThreadCards() -> [Card]? {
        return botScriptDelegate?.fetchThreadCards()
    }
    
    func fetchUserCard() -> Card? {
        return botScriptDelegate?.fetchUserCard()
    }
    
    func fetchBotCard() -> Card? {
        return botScriptDelegate?.fetchBotCard()
    }
    
    func fetchThreadList( _ tids:[String] ) -> ThreadListResult {
        return botScriptDelegate!.fetchThreadList(tids)
    }
    
    func fetchThread() -> ChatThread? {
        return botScriptDelegate?.fetchThread()
    }
    
    func fetchMessageHistory() -> [ChatMessage]? {
        return botScriptDelegate?.fetchMessageHistory()
    }
    
    func doSetOptionButtonItems( _ items:[OptionItem] ) {
        optionButton.items = items
    }
    
    func doEnvironmentFixup( _ env:inout WidgetEnvironment ) {
        env.fullscreen = true
    }
}
