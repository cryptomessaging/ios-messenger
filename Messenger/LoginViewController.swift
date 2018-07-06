import UIKit

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    class func showLogin(_ parent:UIViewController) {
        let vc = LoginViewController(nibName: "LoginView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        parent.present(vc, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginButton.isEnabled = false
        emailField.delegate = self
        passwordField.delegate = self
        
        emailField.text = MyUserDefaults.instance.getLoginId()
        
        passwordField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .login, vc:self )
    }
    
    @IBAction func settingsButtonAction(_ sender: UIBarButtonItem) {
        AdvancedSettingsViewController.showAdvancedSettings(self)
    }
    
    @IBAction func forgotPasswordButtonAction(_ sender: UIButton) {
        let host = MyUserDefaults.instance.getMobidoApiServer()
        let url = URL(string:"\(host)/password-reset")!
        
        AnalyticsHelper.trackScreen( .passwordRecovery, vc:self )
        UIApplication.shared.openURL( url )
    }
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func loginButtonAction(_ sender: UIButton) {
        
        // make sure keyboard has been dismissed
        emailField.endEditing(true)
        passwordField.endEditing(true)
        
        doLogin()
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
                doLogin()
            }
            return false
        } else {
            return true
        }
    }
    
    func validateFields() -> Bool {
        let email = StringHelper.clean( emailField.text )
        if email == nil {
            loginButton.isEnabled = false
            return false
        }
        
        let password = StringHelper.clean( passwordField.text )
        if password == nil {
            loginButton.isEnabled = false
            return false
        }
        
        loginButton.isEnabled = true
        return true
    }
    
    func doLogin() {
        let id = StringHelper.clean( emailField.text )!
        let password = StringHelper.clean( passwordField.text )!
        let authority = StringHelper.isValidEmail( id ) ? "email" : "username"
        let login = Login(authority: authority, id: id, password: password)
    
        let progress = ProgressIndicator(parent: view, message: "Logging in".localized)
        self.loginButton.isEnabled = false
        MobidoRestClient.instance.createAccessKey(login) {
            result -> Void in
            UIHelper.onMainThread {
                progress.stop()
                self.loginButton.isEnabled = true
                self.handleLoginResult(result,forLogin:login,failureDialogTitle:"Login Failed".localized )
            }
        }
    }
    
    // make sure this happens on the main thread
    fileprivate func handleLoginResult(_ result:AccessKeyResult, forLogin:Login, failureDialogTitle:String) {
        
        if let failure = result.failure {
            // Mask the 401 so the login screen doesnt get dismissed
            failure.statusCode = 0
            ProblemHelper.showProblem(self, title: failureDialogTitle, failure: failure )
        } else if result.accessKey == nil || result.accessKey!.isValid() != true {
            ProblemHelper.showProblem(self, title: "Invalid Access Key".localized, message: "Access key missing id or secret".localized, code:0 )
        } else {
            // success!
            let pref = MyUserDefaults.instance
            pref.setLoginId(forLogin.id!)
            pref.setAccessKey(result.accessKey!);
            
            MainViewController.showMain()
        }
    }
}
