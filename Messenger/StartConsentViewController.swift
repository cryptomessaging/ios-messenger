//
//  StartConsentViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/30/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import WebKit
import MessageUI

class StartConsentViewController: UIViewController, UITextFieldDelegate, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var kidnameField: UITextField!
    @IBOutlet weak var parentEmailField: UITextField!
    @IBOutlet weak var printFormButton: UIButton!
    @IBOutlet weak var emailFormButton: UIButton!

    var nextButton:UIBarButtonItem!
    var mynav:UINavigationController!
    var parentKey:ParentKey!
    
    class func presentStartConsent(_ parent:UIViewController) {
        let vc = StartConsentViewController(nibName: "StartConsentView", bundle: nil)
        
        vc.mynav = UINavigationController(rootViewController:vc)
        parent.present( vc.mynav, animated: true, completion:nil )
    }
    
    class func pushStartConsent( _ nav:UINavigationController, parentKey:ParentKey? = nil ) {
        let vc = StartConsentViewController(nibName: "StartConsentView", bundle: nil)
        vc.parentKey = parentKey
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        nextButton = UIBarButtonItem(title: "Next".localized, style: .plain, target: self, action: #selector(nextButtonAction))
        navigationItem.rightBarButtonItem = nextButton
        navigationItem.title = "Print Consent Form".localized
        
        // if there's no back button, add one...
        if navigationItem.backBarButtonItem == nil {
            let backButton = UIBarButtonItem( barButtonSystemItem: .cancel, target: self, action: #selector(backButtonAction))
            navigationItem.leftBarButtonItem = backButton
        }
        
        kidnameField.delegate = self
        parentEmailField.delegate = self
        
        kidnameField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
        parentEmailField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
        
        if let key = parentKey {
            kidnameField.text = key.kidname
            parentEmailField.text = key.parentEmail
        }
        
        validateFields()
        nextButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        // pick an input field to focus on
        if StringHelper.clean( kidnameField.text ) == nil {
            kidnameField.becomeFirstResponder()
        } else if StringHelper.clean( parentEmailField.text ) == nil {
            parentEmailField.becomeFirstResponder()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .startConsent, vc:self )
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        validateFields()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField == kidnameField {
            parentEmailField.becomeFirstResponder()
            return false
        } else if textField == parentEmailField {
            validateFields()
            return false
        } else {
            return true
        }
    }
    
    func validateFields() {
        let kidname = StringHelper.clean( kidnameField.text )
        if kidname == nil {
            emailFormButton.isEnabled = false
            printFormButton.isEnabled = false
            return
        }
        
        let email = StringHelper.clean( parentEmailField.text )
        if StringHelper.isValidEmail( email ) == false {
            emailFormButton.isEnabled = false
            printFormButton.isEnabled = false
            return
        }
        
        emailFormButton.isEnabled = MFMailComposeViewController.canSendMail()
        printFormButton.isEnabled = true
    }
    
    func nextButtonAction(_ sender: UIBarButtonItem) {
        let kidname = StringHelper.clean( kidnameField.text )
        let email = StringHelper.clean( parentEmailField.text )
        ScanConsentViewController.showScanConsent(self.navigationController!,kidname:kidname!,parentEmail:email!)
    }
    
    func backButtonAction(_ sender: UIBarButtonItem) {
        if mynav != nil {
            dismiss(animated: true, completion: nil)
        } else {
            _ = navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func emailFormAction(_ sender: UIButton) {
        let progress = ProgressIndicator(parent:view, message:"Preparing Form (Progress)".localized)
        
        loadHtml() {
            failure, html in
            
            progress.stop()
            if ProblemHelper.showProblem( self, title: "Problem Loading Form (Title)".localized, failure: failure ) {
                return
            }

            let pdf = self.createPDF( html! )
            self.emailPDF( pdf )
        }
    }
    
    @IBAction func printFormAction(_ sender: UIButton) {
        nextButton.isEnabled = true
        
        let progress = ProgressIndicator(parent:view, message:"Preparing Form (Progress)".localized)

        // load webview
        let webview = WKWebView()
        loadHtml() {
            failure, html in
            
            progress.stop()
            if ProblemHelper.showProblem( self, title: "Problem Loading Form (Title)".localized, failure: failure ) {
                return
            }

            webview.loadHTMLString(html! as String, baseURL: nil)
        
            let printController = UIPrintInteractionController.shared
            let printFormatter = webview.viewPrintFormatter()
            printController.printFormatter = printFormatter
        
            let completionHandler: UIPrintInteractionCompletionHandler = { (printController, completed, error) in
                if !completed {
                    if let e = error {
                        DebugLogger.instance.append( function:"printFormAction():failed", error:e )
                    }
                }
            }
        
        //if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
        //    printController.presentFromBarButtonItem(self.nextButton, animated: true, completionHandler: completionHandler)
        //} else {
            printController.present(animated: true, completionHandler: completionHandler)
        //}
        }
    }
    
    //
    // Create an HTML version of the form, auto-populating the kids name and date
    //
    
    fileprivate func loadHtml( _ completion:@escaping (Failure?,String?)->Void) {
        let apiServer = MyUserDefaults.instance.getMobidoApiServer();
        let url = URL(string:"legal/coppa-consent.html", relativeTo: URL(string:apiServer) )
        MobidoRestClient.instance.fetch( url! ) {
            failure, data, response in
            
            if let failure = failure {
                completion(failure,nil)
                return
            }
            
            //let template = try NSString(contentsOfFile: path!, encoding: NSUTF8StringEncoding)
            let template = NSString(data: data!, encoding:String.Encoding.utf8.rawValue)!
            
            // fixup kidname
            let kidname = StringHelper.clean( self.kidnameField.text )
            var html = template.replacingOccurrences( of: "{{kidname}}", with: kidname! )
            
            // date the form
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            let date = formatter.string( from: Date() )
            html = html.replacingOccurrences( of: "{{date}}", with: date )
            
            completion(nil,html)
        }
    }
    
    //
    // Handle PDF of form
    //
    
    func createPDF(_ html:String) -> Data {
        let fmt = UIMarkupTextPrintFormatter(markupText: html)
        
        // 2. Assign print formatter to UIPrintPageRenderer
        
        let render = UIPrintPageRenderer()
        render.addPrintFormatter(fmt, startingAtPageAt: 0)
        
        // 3. Assign paperRect and printableRect
        
        let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4, 72 dpi
        let printable = page.insetBy(dx: 0, dy: 0)
        
        render.setValue(NSValue(cgRect: page), forKey: "paperRect")
        render.setValue(NSValue(cgRect: printable), forKey: "printableRect")
        
        // 4. Create PDF context and draw
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
        
        for i in 1...render.numberOfPages {
            UIGraphicsBeginPDFPage();
            let bounds = UIGraphicsGetPDFContextBounds()
            render.drawPage(at: i - 1, in: bounds)
        }
        
        UIGraphicsEndPDFContext();
        
        // 5. Voila!
        
        //return pdfData.asData()
        return pdfData.copy() as! Data
    }
    
    func emailPDF(_ pdf:Data) {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
            
        // Set the subject and message of the email
        let parentEmail = StringHelper.clean( parentEmailField.text )
        mailComposer.setToRecipients([parentEmail!])
        let kidname = StringHelper.clean( kidnameField.text )
        let subject = String(format:"Please sign this consent form to let %@ use the Mobido app".localized, kidname! )
        mailComposer.setSubject( subject )
        mailComposer.setMessageBody( "Attached is the Mobido consent form".localized, isHTML: false)

        mailComposer.addAttachmentData(pdf, mimeType: "application/pdf", fileName: "Mobido Parent Consent Form.pdf")
        present(mailComposer, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        if result == .sent {
            nextButton.isEnabled = true
        }
        
        controller.dismiss(animated: true, completion: nil)
    }
}
