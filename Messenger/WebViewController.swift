import UIKit

class WebViewController : UIViewController {
    
    fileprivate var webView:UIWebView!
    fileprivate var screenName:AnalyticsHelper.Screen!
    
    class func showWebView( _ parent:UIViewController, url:URL, title:String, screenName:AnalyticsHelper.Screen ) {
        let vc = WebViewController()
        vc.screenName = screenName
        
        vc.webView = UIWebView(frame:vc.view.bounds)
        vc.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(vc.webView)
        
        vc.webView.loadRequest( URLRequest( url: url ) )
        
        if let nav = parent.navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: vc)
            parent.present(nav, animated: true ) {
                nav.title = title
                vc.title = title
                vc.navigationItem.leftBarButtonItem = UIBarButtonItem( title: "Back".localized, style: .plain, target:vc, action: #selector(leftButtonAction) )
            }
        }
    }
    
    class func showWebView( _ nav:UINavigationController, htmlFilename:String, screenName:AnalyticsHelper.Screen ) {
        let vc = WebViewController()
        vc.screenName = screenName
        
        vc.webView = UIWebView(frame:vc.view.bounds)
        vc.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.addSubview(vc.webView)
        
        vc.loadHtml( htmlFilename )

        nav.pushViewController(vc, animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )
        AnalyticsHelper.trackScreen( self.screenName, vc:self )
    }
    
    func leftButtonAction(_ sender: AnyObject ) {
        dismiss(animated: true, completion: nil)
    }
    
    fileprivate func loadHtml( _ htmlFilename:String ) {
        
        if let path = Bundle.main.path(forResource: htmlFilename, ofType:"html", inDirectory:"html") {
            let url = URL(fileURLWithPath:path)
            let request = URLRequest(url:url)
            webView.loadRequest(request)
        } else {
            // programming error! could not find file...
            let html = String(format:"Failed to load HTML from %@".localized, htmlFilename )
            webView.loadHTMLString(html, baseURL:nil)
        }
    }
}
