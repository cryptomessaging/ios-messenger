//
//  DirectNoticeFormViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/13/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import UIKit

class DirectNoticeFormViewController : UIViewController, UITextFieldDelegate {
    
    var sendButton: UIBarButtonItem!
    @IBOutlet weak var kidnameField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    
    class func showDirectNoticeForm(_ nav:UINavigationController) {
        let vc = DirectNoticeFormViewController(nibName: "DirectNoticeFormView", bundle: nil)
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        sendButton = UIBarButtonItem(title: "Send (Direct Notice)".localized, style: .plain, target: self, action: #selector(sendButtonAction))
        sendButton.isEnabled = false
        navigationItem.rightBarButtonItem = sendButton
        navigationItem.title = "Request (Parent) Permission".localized
        
        // track field changes to know when send button should be enabled
        kidnameField.addTarget(self,action:#selector(kidnameChanged),for:.editingChanged)
        kidnameField.delegate = self
        emailField.addTarget(self,action:#selector(emailChanged),for:.editingChanged)
        emailField.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .directNoticeForm, vc:self )
    }
    
    func textFieldShouldReturn( _ textField:UITextField ) -> Bool {
        textField.resignFirstResponder()
        if textField == kidnameField {
            emailField.becomeFirstResponder()
        } else {
            
        }

        return true
    }
    
    func kidnameChanged() {
        sendButton.isEnabled = verifyFields()
    }
    
    func emailChanged() {
        sendButton.isEnabled = verifyFields()
    }
    
    func verifyFields() -> Bool {
        if StringHelper.clean( kidnameField.text ) == nil {
            return false
        }
        
        return StringHelper.isValidEmail( emailField.text )
    }
    
    @IBAction func sendButtonAction(_ sender: UIBarButtonItem) {
        let notice = ParentNotice()
        notice.kidname = StringHelper.clean( kidnameField.text )
        notice.parentEmail = StringHelper.clean( emailField.text )
        
        // start spinner
        sendButton.isEnabled = false
        let progress = ProgressIndicator(parent: view, message: "Sending (Direct) Notice".localized )
        
        MobidoRestClient.instance.sendParentNotice(notice) {
            result in
            
            DispatchQueue.main.async(execute: {
                progress.stop()
                self.sendButton.isEnabled = true
                
                if let failure = result.failure {
                    ProblemHelper.showProblem(self, title: "Sending Notice Failed".localized, failure:failure )
                } else {
                    // save parentEmail and kidname for signup
                    let prefs = MyUserDefaults.instance
                    prefs.set( .SIGNUP_KIDNAME, withValue: notice.kidname )
                    prefs.set( .SIGNUP_PARENT_EMAIL, withValue: notice.parentEmail )
                    
                    DirectNoticeSentViewController.showDirectNoticeSent(self.navigationController!)
                }
            })
        }
    }
    
    @IBAction func backButtonAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
