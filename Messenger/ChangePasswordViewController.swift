import UIKit

class ChangePasswordViewController : UIViewController, UITextFieldDelegate {
    
    var saveButton: UIBarButtonItem!
    @IBOutlet weak var newPasswordField: UITextField!
    @IBOutlet weak var newPasswordField2: UITextField!
    
    class func showChangePassword(_ nav:UINavigationController) {
        let vc = ChangePasswordViewController(nibName: "ChangePasswordView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        nav.pushViewController(vc, animated: true )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        saveButton = UIBarButtonItem(title: "Save Password (Button)".localized, style: .plain, target: self, action: #selector(saveButtonAction))
        navigationItem.rightBarButtonItem = saveButton
        navigationItem.title = "Change Password (Title)".localized
        
        trackChanges(newPasswordField)
        trackChanges(newPasswordField2)
 
        saveButton.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )
        AnalyticsHelper.trackScreen( .changePassword, vc:self )
    }
    
    fileprivate func trackChanges(_ field:UITextField) {
        field.delegate=self
        field.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        saveButton.isEnabled = validateFields()
    }
    
    fileprivate func validateFields() -> Bool {
        if let p1 = StringHelper.clean( newPasswordField.text ) {
            if let p2 = StringHelper.clean( newPasswordField2.text ) {
                return p1 == p2
            }
        }
        
        return false
    }
    
    func textFieldShouldReturn( _ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField === newPasswordField {
            newPasswordField2.becomeFirstResponder()
        }
        
        return false
    }
    
    func saveButtonAction(_ sender: UIBarButtonItem) {
        let newPassword = NewPassword()
        newPassword.password = StringHelper.clean(newPasswordField.text)
        
        let progress = ProgressIndicator(parent: view, message: "Changing password".localized )
        saveButton.isEnabled = false
        MobidoRestClient.instance.changePassword(newPassword ) {
            result in
            
            UIHelper.onMainThread {
                progress.stop()
                self.saveButton.isEnabled = true
                if let failure = result.failure {
                    ProblemHelper.showProblem(self, title: "Problem changing password".localized, failure: failure )
                } else {
                    AnalyticsHelper.trackResult(.passwordChanged)
                    if let nav = self.navigationController {
                        nav.popViewController(animated: false)
                    }
                }
            }
        }
    }
}
