import UIKit

class LandingViewController: UIViewController {
    
    class func create() -> UIViewController {
        let vc = LandingViewController(nibName: "LandingView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        
        let nav = UINavigationController()
        nav.viewControllers = [vc]
        
        return nav
    }
    
    class func showLandingPage() {
        NavigationHelper.fadeInNewRootVC( create() )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.extendedLayoutIncludesOpaqueBars = true
        self.edgesForExtendedLayout = UIRectEdge()
        self.setNeedsStatusBarAppearanceUpdate()
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
    
    @IBAction func loginButtonAction(_ sender: UIButton ) {
        LoginViewController.showLogin(self)
    }
    
    @IBAction func imNewButtonAction(_ sender: UIButton) {
        AskBirthdayViewController.showAskBirthday(self.navigationController!)
    }
}

