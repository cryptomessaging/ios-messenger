import UIKit

class AdvancedSettingsViewController: UITableViewController {
    
    @IBOutlet weak var serverUrlLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildTimeLabel: UILabel!
    @IBOutlet weak var widgetDeveloperSwitch: UISwitch!
    @IBOutlet weak var locationDeveloperSwitch: UISwitch!
    @IBOutlet weak var loggingSwitch: UISwitch!
    @IBOutlet weak var botProxyPattern: UILabel!
    @IBOutlet weak var botProxyReplacement: UILabel!
    @IBOutlet weak var passcodeLabel: UILabel!
    
    fileprivate var unwinder:(()->Void)?
    
    class func showAdvancedSettings(_ vc:UIViewController) {
        let result:(vc:AdvancedSettingsViewController,unwinder:()->Void) = NavigationHelper.show(vc,storyboard:"AdvancedSettings", id:"AdvancedSettingsViewController")
        result.vc.unwinder = result.unwinder
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let prefs = MyUserDefaults.instance
        let url = prefs.getMobidoApiServer()
        serverUrlLabel.text = url
        
        let date = compileDate() ?? ""
        let time = compileTime() ?? ""
        buildTimeLabel.text = "Built \(date), \(time)"
        
        if let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String {
            versionLabel.text = "Version \(version)"
        }
        
        widgetDeveloperSwitch.setOn( prefs.check(.IsWidgetDeveloper), animated: false)
        locationDeveloperSwitch.setOn( prefs.check(.IsLocationDeveloper), animated: false)
        loggingSwitch.setOn( prefs.check(.IsLogging), animated: false)
        
        if let pattern = prefs.get( .BOT_PROXY_PATTERN ) {
            botProxyPattern.text = pattern
        }
        if let replacement = prefs.get( .BOT_PROXY_REPLACEMENT ) {
            botProxyReplacement.text = replacement
        }
        
        updatePasscodeRow()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .advancedSettings, vc:self )
    }
    
    @IBAction func widgetDeveloperToggled(_ sender: UISwitch) {
        MyUserDefaults.instance.set( .IsWidgetDeveloper, value:sender.isOn )
    }
    
    @IBAction func locationDeveloperToggled(_ sender: UISwitch) {
        MyUserDefaults.instance.set( .IsLocationDeveloper, value:sender.isOn )
    }
    
    @IBAction func loggingToggled(_ sender: UISwitch) {
        MyUserDefaults.instance.set( .IsLogging, value:sender.isOn )
        DebugLogger.instance.logging = sender.isOn
    }
    
    func leftButtonAction(_ sender: AnyObject ) {
        unwinder?()
    }
    
    fileprivate func editServerUrl() {
        let alert = UIAlertController(title: "API Server".localized, message: nil, preferredStyle: .alert )
        let prefs = MyUserDefaults.instance
        alert.addTextField {
            field in
            field.text = prefs.getMobidoApiServer()
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            if let url = StringHelper.clean( alert.textFields!.first!.text ) {
                self.serverUrlLabel.text = url
                prefs.setMobidoAPIServer( url )
            } else {
                self.serverUrlLabel.text = MyUserDefaults.DEFAULT_MOBIDO_API_SERVER
                prefs.setMobidoAPIServer( nil )
            }
            
            // on update, force a new login
            LogoutHelper.logout(preserveLoginId: true)
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func editBotProxy(_ title:String, key:MyUserDefaults.StringKey, label:UILabel ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert )
        let prefs = MyUserDefaults.instance
        alert.addTextField {
            field in
            field.text = prefs.get( key )
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            let value = StringHelper.clean( alert.textFields!.first!.text )
            label.text = value
            prefs.set( key, withValue:value )
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func editMarketPasscode() {
        let alert = UIAlertController(title: "Market Passcode (Title)".localized, message: nil, preferredStyle: .alert )
        let prefs = MyUserDefaults.instance
        alert.addTextField {
            field in
            
            field.isSecureTextEntry = true
            field.text = prefs.get( .MARKET_PASSCODE )
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: {
            action in
            
            if let passcode = StringHelper.clean( alert.textFields!.first!.text ) {
                prefs.set( .MARKET_PASSCODE, withValue: passcode )
            } else {
                prefs.set( .MARKET_PASSCODE, withValue: nil )
            }
            self.updatePasscodeRow()
        }))
        present(alert, animated: true, completion: nil)
    }
    
    fileprivate func updatePasscodeRow() {
        if MyUserDefaults.instance.get( .MARKET_PASSCODE ) == nil {
            passcodeLabel.text = "Set passcode".localized
        } else {
            passcodeLabel.text = "Passcode is set".localized
        }
    }
    
    fileprivate var serverClicks = 0
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch (indexPath.section, indexPath.row) {
        case (0,1):
            serverClicks += 1
            if serverClicks > 16 {
                tableView.reloadData()   // show bot proxy fields
            }
        case (1,0):
            editServerUrl()
        case (2,3):
            DebugLogViewController.showDebugLog(self.navigationController!)
        case (3,0):
            editBotProxy("Bot Proxy Pattern (Title)".localized, key:.BOT_PROXY_PATTERN, label:botProxyPattern )
        case (3,1):
            editBotProxy("Bot Proxy Replacement (Title)".localized, key:.BOT_PROXY_REPLACEMENT, label:botProxyReplacement )
        case (4,0):
            editMarketPasscode()
        default:
            print( "Unknown" )
        }
        
        // deselect to remove gray background
        self.tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // Hide Bot Proxy section until 16 clicks
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if isSectionHidden(section) {
            return 0.0
        } else {
            return super.tableView(tableView, heightForHeaderInSection: section )
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSectionHidden(section) {
            return 0
        } else {
            return super.tableView(tableView, numberOfRowsInSection:section )
        }
    }
    
    fileprivate func isSectionHidden(_ section:Int) -> Bool {
        return serverClicks < 16 && (section == 1 || section == 3 || section == 4 )
    }
}

