import UIKit

class MoreViewController: UITableViewController {
    
    // MARK: Properties
    @IBOutlet weak var chatAutocorrectionLabel: UILabel!
    @IBOutlet weak var themeLabel: UILabel!
    @IBOutlet weak var soundSettingLabel: UILabel!
    @IBOutlet weak var accountIdLabel: UILabel!
    
    class func createMoreViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "MoreView", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MoreView") as UIViewController
        
        let nav = UINavigationController()
        nav.viewControllers = [vc]
        
        return nav
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = UIRectEdge()
        navigationItem.title = "Settings (Title)".localized
        
        let prefs = MyUserDefaults.instance
        if let login = prefs.getLoginId() {
            accountIdLabel.text = login
        } else {
            accountIdLabel.text = "Create new login".localized
        }
        
        updateAutocorrection()
        updateThemeLabel()
        updateSoundSettingLabel()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear( animated )
        AnalyticsHelper.trackScreen( .more, vc:self )
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch (indexPath.section, indexPath.row) {
        case (0,0):
            changeAutocorrection()
        case (0,1):
            changeTheme()
        case (0,2):
            changeSoundSetting()
        case (0,3):
            AdvancedSettingsViewController.showAdvancedSettings(self)
        
        case (1,0):
            ListLoginsViewController.showLoginList( self.navigationController!)
        case (1,1):
            ChangePasswordViewController.showChangePassword( self.navigationController!)
        case (1,2):
            sync()
        case (1,3):
            confirmLogout()
        
        case (2,0):
            //AnalyticsHelper.trackView(.FAQ)
            WebViewController.showWebView(self.navigationController!, htmlFilename: "faq", screenName: .faq)
        case (2,1):
            let url = URL(string: "mailto:feedback@mobido.com")
            UIApplication.shared.openURL(url!)
        case (2,2):
            //AnalyticsHelper.trackView(.TermsOfService)
            let apiServer = MyUserDefaults.instance.getMobidoApiServer();
            let url = URL(string:"legal/terms-of-service.html", relativeTo: URL(string:apiServer) )
            WebViewController.showWebView(self, url:url!, title:"Terms of Service (Title)".localized, screenName: .termsOfService )
        case (2,3):
            //AnalyticsHelper.trackView(.About)
            WebViewController.showWebView(self.navigationController!, htmlFilename: "about", screenName: .about )
        case (2,4):
            QuickstartViewController.pushQuickstart(self.navigationController!)
        default:
            print( "Unknown" )
        }
        
        // deselect to remove gray background
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //
    // Theme picker
    //
    
    fileprivate func changeTheme() {
        let options = ListPickerOptions()
        options.screenName = .changeTheme
        options.result = .themeChanged
        options.selected = MyUserDefaults.instance.getTheme()
        ListPickerViewController.showPicker(self.navigationController!, title:"Select Theme (Title)".localized, items: ThemeHelper.THEME_LIST, options:options ) {
            result in
            
            MyUserDefaults.instance.setTheme(result.key)
            self.updateThemeLabel()
        }
    }
    
    fileprivate func updateThemeLabel() {
        let selected = MyUserDefaults.instance.getTheme()
        let label = ThemeHelper.asThemeLabel(selected)
        let text = String( format:"%@ Theme (Selected)".localized, label )
        themeLabel.text = text
    }
    
    //
    // Chat text autocorrection
    //
    
    fileprivate func changeAutocorrection() {
        let prefs = MyUserDefaults.instance
        prefs.set(.DisableChatTextAutocorrection, value: !prefs.check(.DisableChatTextAutocorrection) ) // reverse it
        updateAutocorrection()
    }
    
    fileprivate func updateAutocorrection() {
        let isDisabled = MyUserDefaults.instance.check(.DisableChatTextAutocorrection)
        let label = isDisabled ? "DO NOT autocorrect chat typing".localized : "Autocorrect chat typing".localized
        chatAutocorrectionLabel.text = label
    }
    
    // Sound setting
    
    fileprivate func changeSoundSetting() {
        let options = ListPickerOptions()
        options.screenName = .changeSoundSetting
        options.result = .soundSettingChanged
        options.selected = MyUserDefaults.instance.getSoundSetting()
        ListPickerViewController.showPicker(self.navigationController!, title:"Sound Setting (Title)".localized, items: SoundHelper.SETTING_LIST, options:options ) {
            result in
            
            MyUserDefaults.instance.setSoundSetting(result.key)
            self.updateSoundSettingLabel()
        }
    }
    
    fileprivate func updateSoundSettingLabel() {
        let selected = MyUserDefaults.instance.getSoundSetting()
        let label = SoundHelper.asLabel(selected)
        soundSettingLabel.text = label
    }
    
    // More...
    
    fileprivate func sync() {
        let progress = ProgressIndicator(parent: view, message: "Syncing".localized )
        
        // clear everything BUT our login credentials
        SyncHelper.syncAsync(progress) {
            success in
            DispatchQueue.main.async {
                progress.stop()
                AnalyticsHelper.trackResult(.synced)
            }
        }
    }
    
    fileprivate func confirmLogout() {
        let alert = UIAlertController(title: "Logout?".localized, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            LogoutHelper.logout(preserveLoginId: false)
        }))
        present(alert, animated: true, completion: nil)
    }
}
