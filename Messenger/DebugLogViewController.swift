import Foundation
import UIKit
import MessageUI

class DebugLogViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet weak var webview: UIWebView!
    
    class func showDebugLog(_ nav:UINavigationController) {
        NavigationHelper.push( nav, storyboard:"DebugLog", id:"DebugLogViewController" )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        reload()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .debugLog, vc:self )
    }
    
    fileprivate func reload() {
        let data = DebugLogger.instance.read()
        let baseUrl = URL(string:".")!
        webview.load(data, mimeType: "text/plain", textEncodingName: "UTF-8", baseURL: baseUrl)
        
        // scroll to bottom
        UIHelper.delay(0.3 ) {
            let height = self.webview.stringByEvaluatingJavaScript( from: "document.body.offsetHeight;")
            let js = NSString( format:"window.scrollBy(0,%@)", height! ) as String
            self.webview.stringByEvaluatingJavaScript(from: js)
        }
    }
    
    @IBAction func moreAction(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        let refreshAction = UIAlertAction(title: "Refresh".localized, style: .default, handler: {
            action in
            self.reload()
        })
        alert.addAction( refreshAction )
        
        let emailAction = UIAlertAction(title: "Email to support".localized, style: .default, handler: {
            action in
            self.emailLogToSupport()
        })
        alert.addAction(emailAction)
        
        let clearAction = UIAlertAction(title: "Clear".localized, style: .destructive, handler: {
            action in
            
            DebugLogger.instance.clear()
            self.reload()
        })
        alert.addAction(clearAction)
        
        UIHelper.ipadFixup( alert, barButtonItem: sender )
        present(alert, animated: true, completion: nil)
    }
    
    //
    // MARK: Email log to mobido support
    //
    
    fileprivate func emailLogToSupport() {
        
        let account = StringHelper.ensure( MyUserDefaults.instance.getLoginId() )
        let body = DebugLogger.instance.readString()
        let version = StringHelper.ensure( Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String )
        let model = UIDevice.current.localizedModel
        
        let composeVC = MFMailComposeViewController()
        composeVC.mailComposeDelegate = self
        
        // Configure the fields of the interface.
        composeVC.setToRecipients(["support@mobido.com"])
        composeVC.setSubject("Debug from \(account) on \(model) v\(version)")
        composeVC.setMessageBody( body, isHTML: false)
        
        if MFMailComposeViewController.canSendMail() {
            // Present the view controller modally.
            present(composeVC, animated: true, completion: nil)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        navigationController!.popViewController(animated: true)
    }
}
