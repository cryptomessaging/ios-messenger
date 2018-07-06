//
//  ConsentStatusViewController.swift
//  Messenger
//
//  Created by Mike Prince on 11/4/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class ConsentStatusViewController : UIViewController {
    
    var nav:UINavigationController!
    @IBOutlet weak var notifiedCheckmark: UIImageView!
    @IBOutlet weak var consentedCheckmark: UIImageView!
    @IBOutlet weak var verifiedCheckmark: UIImageView!
    @IBOutlet weak var accountCheckmark: UIImageView!
    

    @IBOutlet weak var denyConsentButton: UIButton!
    @IBOutlet weak var accountButton: UIButton!
    
    fileprivate var child:MyChild!
    fileprivate let checkmarkImage = UIImage(named: "Checkmark")
    fileprivate var hasConsent = false
    
    class func showConsentStatus(_ parent:UIViewController, child:MyChild) {
        let vc = ConsentStatusViewController(nibName: "ConsentStatusView", bundle: nil)
        vc.child = child
        vc.edgesForExtendedLayout = UIRectEdge()
        
        vc.nav = UINavigationController(rootViewController:vc)
        parent.present( vc.nav, animated: true ) {
            vc.nav.title = child.kidname
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation
        edgesForExtendedLayout = UIRectEdge()
        let backButton = UIBarButtonItem(title:"Back".localized, style: .plain, target: self, action: #selector(backAction))
        navigationItem.leftBarButtonItem = backButton
        let nextButton = UIBarButtonItem(title:"Next".localized, style: .plain, target: self, action: #selector(nextAction))
        navigationItem.rightBarButtonItem = nextButton
        navigationItem.title = child.kidname
        
        notifiedCheckmark.image = checkmarkImage
        
        if let coppa = child.acmValue("coppa") {
            switch coppa {
            case "consented":
                consentedCheckmark.image = checkmarkImage
                hasConsent = true
            case "verified":
                hasConsent = true
                consentedCheckmark.image = checkmarkImage
                verifiedCheckmark.image = checkmarkImage
            default: break    
            }
        }
        
        denyConsentButton.isEnabled = hasConsent
        
        if child.uid != nil {
            accountCheckmark.image = checkmarkImage
        } else {
            accountButton.isEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .consentStatus, vc:self )
    }
    
    func backAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil )
    }

    func accountAction(_ sender: UIButton) {
        KidDetailViewController.showKidDetail(nav, child: child)
    }
    
    @IBAction func denyConsentAction(_ sender: UIButton) {
        AlertHelper.showAlert(self, title: "Deny Consent (Alert Title)".localized, message:"This WILL NOT remove your childs account.  This WILL remove potential personal information including all pictures, and disable further pictures.  Continue?".localized, okStyle: .destructive ) {

            let progress = ProgressIndicator(parent: self.view, message: "Denying Consent (Progress)".localized )
            self.denyConsentButton.isEnabled = false
            
            let parentKey = ParentKey()
            parentKey.parentEmail = self.child.parentEmail
            parentKey.kidname = self.child.kidname
            MobidoRestClient.instance.denyParentConsent(parentKey) {
                result in
                
                DispatchQueue.main.async(execute: {
                    progress.stop()
                    
                    if ProblemHelper.showProblem(self, title: "Problem denying consent (Alert Title)".localized, failure: result.failure ) {
                        AnalyticsHelper.trackResult(.denyConsentFailed)
                        self.denyConsentButton.isEnabled = true   // let them try again
                    } else {
                        AnalyticsHelper.trackResult(.deniedConsent)
                        
                        // reset our local display
                        self.hasConsent = false
                        self.consentedCheckmark.image = nil
                        self.verifiedCheckmark.image = nil
                    }
                })
            }
        }
    }
    
    // can go three ways:
    // if no consent => start consent
    // if no child account => pop-up "Create child account"
    // else, view kid detail
    func nextAction(_ sender: UIBarButtonItem) {
        if !hasConsent {
            let parentKey = ParentKey(forChild:child)
            StartConsentViewController.pushStartConsent(nav, parentKey:parentKey)
        } else if child.uid == nil {
            popupCreateChildAccount()
        } else {
            KidDetailViewController.showKidDetail(nav, child: child)
        }
    }
    
    func popupCreateChildAccount() {
        AlertHelper.showOkAlert(self, title: "Create Child Account (Alert Title)".localized, message:"Please help your child create a Mobido account.  Have them download Mobido to their device, and tap 'I'm new here' on the welcome screen".localized ) {
        }
    }
}
