import Foundation
import UIKit

class ContentFlaggerViewController: UIViewController, UITextViewDelegate {
    
    enum ContentType : String {
        case Thread
        case ThreadMessage
        case Card
    }
    
    fileprivate var flagging = ContentFlagging()
    fileprivate var contentType:ContentType!
    
    @IBOutlet weak var reasonTextField: UITextView!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationItem!
    
    class func showContentFlagger( _ nav:UINavigationController, type:ContentType, id:String ) {
        let vc = ContentFlaggerViewController(nibName: "ContentFlaggerView", bundle: nil )
        nav.present(vc, animated: true, completion:nil )
        
        vc.flagging.type = type.rawValue
        vc.flagging.id = id
        vc.contentType = type
        
        vc.edgesForExtendedLayout = UIRectEdge()
        vc.reasonTextField.becomeFirstResponder()
        vc.reasonTextField.delegate = vc
        vc.saveButton.isEnabled = false
        
        var typeName:String;
        switch type {
        case .Thread:
            typeName = "Chat".localized
        case .ThreadMessage:
            typeName = "Message".localized
        case .Card:
            typeName = "Card".localized
        }
        
        vc.navBar.title = String(format:"Flag %@".localized, typeName )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        switch contentType! {
        case .Thread:
            AnalyticsHelper.trackScreen( .flagChat, vc:self )
        case .ThreadMessage:
            AnalyticsHelper.trackScreen( .flagMessage, vc:self )
        case .Card:
            AnalyticsHelper.trackScreen( .flagCard, vc:self )
        }
    }
    
    //
    // MARK: Validate reason
    //
    
    func textViewDidChange(_ textView:UITextView) {
        saveButton.isEnabled = StringHelper.clean(reasonTextField.text) != nil
    }
    
    //
    // MARK: Button handlers
    //
    
    @IBAction func saveAction(_ sender: UIBarButtonItem) {
        let progress = ProgressIndicator(parent: view, message: "Reporting Issue".localized)
        saveButton.isEnabled = false
        
        flagging.reason = reasonTextField.text
        MobidoRestClient.instance.flagContent( flagging ) {
            result in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                
                self.saveButton.isEnabled = true
                if let failure = result.failure {
                    ProblemHelper.showProblem(self, title: "Failed to report issue".localized, failure: failure)
                    return
                }
                
                let type = self.contentType!
                switch type {
                case .Thread:
                    AnalyticsHelper.trackResult(.chatFlagged)
                case .ThreadMessage:
                    AnalyticsHelper.trackResult(.messageFlagged)
                case .Card:
                    AnalyticsHelper.trackResult(.cardFlagged)
                }
                self.unwind()
            })
        }
    }
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        unwind()
    }
    
    fileprivate func unwind() {
        dismiss(animated: true, completion: nil)
    }
}
