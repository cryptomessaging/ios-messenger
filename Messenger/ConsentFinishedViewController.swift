//
//  ConsentFinishedViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/30/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

class ConsentFinishedViewController: UIViewController, UITextFieldDelegate {
    
    class func showConsentFinished(_ nav:UINavigationController) {
        let vc = ConsentFinishedViewController(nibName: "ConsentFinishedView", bundle: nil)
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        let doneButton = UIBarButtonItem(title: "(Consent) Done".localized, style: .plain, target: self, action: #selector(doneButtonAction))
        navigationItem.rightBarButtonItem = doneButton
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .consentFinished, vc:self )
    }
    
    func doneButtonAction(_ sender: UIBarButtonItem) {
        // pop to the view controller just before StartConsentViewController
        let nav = navigationController!
        for vc in nav.viewControllers {
            if vc is StartConsentViewController {
                if let pos = nav.viewControllers.index( of: vc ) {
                    if pos == 0 {
                        self.dismiss(animated: true, completion: nil)
                    } else {
                        let root = nav.viewControllers[pos - 1]
                        nav.popToViewController(root, animated: true)
                    }
                }
            }
        }
    }
}
