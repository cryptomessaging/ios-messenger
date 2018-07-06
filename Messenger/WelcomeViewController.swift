import UIKit

class WelcomeViewController: UIViewController {
    
    @IBOutlet weak var authorizeButton: UIButton!
    
    class func create() -> UIViewController {
        let vc = WelcomeViewController(nibName: "WelcomeView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        
        let nav = UINavigationController()
        nav.viewControllers = [vc]
        
        return nav
    }
    
    class func showWelcome() {
        NavigationHelper.fadeInNewRootVC( create() )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.extendedLayoutIncludesOpaqueBars = true
        self.edgesForExtendedLayout = UIRectEdge()
        self.setNeedsStatusBarAppearanceUpdate()
        
        authorizeButton.layer.cornerRadius = 8
        //authorizeButton.titleEdgeInsets = UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: -20.0)
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewWillAppear(_ animated:Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .welcome, vc:self )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillDisappear(animated)
    }
    
    @IBAction func directNoticeButtonAction(_ sender: UIButton) {
    }
    
    @IBAction func loginButtonAction(_ sender: UIButton) {
        LoginViewController.showLogin(self)
    }
    
    @IBAction func authorizeAction(_ sender: UIButton) {
        StartConsentViewController.pushStartConsent(self.navigationController!)
    }
    
    @IBAction func imNewButtonAction(_ sender: UIButton) {
        AskBirthdayViewController.showAskBirthday(self.navigationController!)
        //QuickstartViewController.pushQuickstart(self.navigationController!)
    }
}
