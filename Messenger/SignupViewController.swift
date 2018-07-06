//
//  SignupViewController.swift
//  Messenger
//
//  Created by Mike Prince on 11/25/15.
//  Copyright © 2015 Mike Prince. All rights reserved.
//

import UIKit

class SignupViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var signupButton: UIButton!
    @IBOutlet weak var emailLabel: UILabel!
    
    var isUnder13 = false
    
    class func showSignup(_ parent:UIViewController) {
        let vc = SignupViewController(nibName: "SignupView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        parent.present(vc, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        signupButton.isEnabled = false
        emailField.delegate = self
        passwordField.delegate = self
        
        emailField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
        passwordField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        // if under 13, revise placeholders and disallow email
        let ymd = MyUserDefaults.instance.get( .SIGNUP_BIRTHDAY )!
        if let birthday = TimeHelper.parseYmdToDate( ymd ) {
            if TimeHelper.calculateAge(birthday) < 13 {
                isUnder13 = true
                emailField.placeholder = "Choose a username".localized
                emailLabel.text = "Username (Label)".localized
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .signup, vc:self )
    }
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func signupAction(_ sender: UIButton) {
        
        // make sure keyboard has been dismissed
        emailField.endEditing(true)
        passwordField.endEditing(true)
        
        doSignup()
    }
    
    @IBAction func showInformationPractices(_ sender: UIButton) {
        let apiServer = MyUserDefaults.instance.getMobidoApiServer();
        let url = URL(string:"legal/information-practices.html", relativeTo: URL(string:apiServer) )
        WebViewController.showWebView(self, url:url!, title:"Information Practices (Title)".localized, screenName: .informationPractices )
    }
    
    func adviseAgainstEmail() {
        let alertController = UIAlertController(title: nil, message: "Children under 13 cannot use an email address to sign up".localized, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK".localized, style: .default) { (action) in
            //self.dismissViewControllerAnimated(true, completion: nil)
        }
        alertController.addAction(OKAction)
        
        present(alertController, animated: true, completion: nil )
    }
    
    func doSignup() {
        let id = StringHelper.clean( emailField.text )!
        let isValidEmail = StringHelper.isValidEmail( id )
        
        // make sure under13 doesn't use email
        if isUnder13 && isValidEmail {
            adviseAgainstEmail()
            return
        }
        
        signupButton.isEnabled = false
        let authority = isValidEmail ? "email" : "username"
        let password = StringHelper.clean( passwordField.text )!
        let account = NewAccount(authority: authority, id: id, password: password, login:true)
        
        account.birthday = MyUserDefaults.instance.get(.SIGNUP_BIRTHDAY)
        account.kidname = MyUserDefaults.instance.get(.SIGNUP_KIDNAME)
        account.parentEmail = MyUserDefaults.instance.get(.SIGNUP_PARENT_EMAIL)
        
        // start spinner
        let progress = ProgressIndicator(parent: view, message: "Signing up".localized )
        signupButton.isEnabled = false
        
        MobidoRestClient.instance.createAccount(account) {
            result in
            
            if let failure = result.failure {
                progress.stop()
                self.signupButton.isEnabled = true
                ProblemHelper.showProblem(self, title: "Sign Up Failed".localized, failure:failure )
                return
            }
            
            // success!
            let pref = MyUserDefaults.instance
            pref.setLoginId(id)
            pref.setAccessKey(result.accessKey!);
            
            // we know reputations and cards are empty, so fill local cache to avoid race condition when fetching them
            GeneralCache.instance.saveMyReputations([String:Reputation]())  // empty reputations
            GeneralCache.instance.saveMyCardList([Card]())  // empty list
            
            // register APN token with new account if available
            guard let token = PushRegistration.instance.currentDeviceToken else {
                // no APN token, so skip to next step...
                self.finishSignup( progress )
                return
            }
            
            MobidoRestClient.instance.registerApnToken( token ) {
                result in
                
                if ProblemHelper.showProblem(self, title: "Problem registering APN token (Alert Title)".localized, failure: result.failure ) {
                    progress.stop()
                    self.signupButton.isEnabled = true
                } else {
                    self.finishSignup( progress )
                }
            }
        }
    }
    
    func finishSignup(_ progress:ProgressIndicator) {
        UIHelper.onMainThread {
            progress.stop() // TODO we really dont need this, do we?  The screen is going away...
            //self.signupButton.enabled = true
            
            self.dismiss(animated: true) {
                MainViewController.showMain()
            }
        }
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        _ = validateFields()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField == emailField {
            passwordField.becomeFirstResponder()
            return false
        } else if textField == passwordField {
            if validateFields() {
                doSignup()
            }
            return false
        } else {
            return true
        }
    }
    
    func validateFields() -> Bool {
        let email = StringHelper.clean( emailField.text )
        if email == nil {
            signupButton.isEnabled = false
            return false
        }
        
        let password = StringHelper.clean( passwordField.text )
        if password == nil {
            signupButton.isEnabled = false
            return false
        }
        
        signupButton.isEnabled = true
        return true
    }
}
