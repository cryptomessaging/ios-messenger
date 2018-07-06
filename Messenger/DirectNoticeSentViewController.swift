//
//  DirectNoticeSentViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/13/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class DirectNoticeSentViewController : UIViewController {
    
    class func showDirectNoticeSent(_ nav:UINavigationController) {
        // unwind navigation stack, so back will go to straight to welcome screen
        while nav.viewControllers.count > 1 {
            nav.popViewController( animated: false )
        }
        
        let vc = DirectNoticeSentViewController(nibName: "DirectNoticeSentView", bundle: nil)
        vc.edgesForExtendedLayout = UIRectEdge()
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .directNoticeSent, vc:self )
    }
    
    @IBAction func continueButtonAction(_ sender: UIButton) {
        let nav = self.navigationController!
        nav.popViewController( animated: false )
        SignupViewController.showSignup(nav)
    }
}
