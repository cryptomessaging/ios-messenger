//
//  KidDetailViewController.swift
//  Messenger
//
//  Created by Mike Prince on 11/2/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class KidDetailViewController : UIViewController {
    
    @IBOutlet weak var reviewAccountButton: UIButton!
    @IBOutlet weak var deleteAccountButton: UIButton!
    @IBOutlet weak var toggleChildAccessButton: UIButton!
    
    fileprivate var child:MyChild!
    fileprivate var childAccountStatus:ChildAccountStatusResult!

    class func showKidDetail(_ nav:UINavigationController, child:MyChild) {
        let vc = KidDetailViewController(nibName: "KidDetailView", bundle: nil)
        vc.child = child
        vc.edgesForExtendedLayout = UIRectEdge()
        nav.pushViewController(vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelAction))
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.title = child.kidname
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        // ask server whether account is disabled or not
        updateToggleButton()
        if childAccountStatus == nil {
            MobidoRestClient.instance.fetchChildAccountStatus( child.uid! ) {
                result in
                
                if !ProblemHelper.showProblem(self, title: "Problem Fetching Child Account Status (Problem Title)".localized, failure: result.failure ) {
                    UIHelper.onMainThread {
                        self.childAccountStatus = result
                        self.updateToggleButton()
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .kidDetail, vc:self )
    }
    
    func updateToggleButton() {
        if let status = childAccountStatus, let disabled = status.disabled {
            let title = disabled ? "Enable Child Account (Button)".localized : "Disable Child Account (Button)".localized
            toggleChildAccessButton.setTitle(title, for: UIControlState() )
            toggleChildAccessButton.isEnabled = true
        } else {
            toggleChildAccessButton.isEnabled = false
            toggleChildAccessButton.setTitle("Toggle Child Account (Button)".localized, for: UIControlState())
        }
    }
    
    @IBAction func cancelAction(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil )
    }
    
    @IBAction func reviewAccountAction(_ sender: UIButton) {
        AlertHelper.showAlert(self, title: "Switch to Child's Account? (Alert Title)".localized, message:"Tap OK to sign into your childs account.  You will NOT be able to post new content, but you can delete messages".localized, okStyle: .default ) {
            
            AnalyticsHelper.trackAction(.reviewAccount)
            let progress = ProgressIndicator(parent: self.view, message: "Fetching Child Access Key (Progress)".localized )
            self.reviewAccountButton.isEnabled = false
            
            MobidoRestClient.instance.createChildAccessKey( self.child.uid! ) {
                result in
                
                UIHelper.onMainThread {
                    progress.stop()
                    self.reviewAccountButton.isEnabled = true
                    self.loginAsChild(result)
                }
            }
        }
    }
    
    // make sure I'm in main thread
    func loginAsChild(_ result:AccessKeyResult) {
        if let failure = result.failure {
            // Mask the 401 so the login screen doesnt get dismissed
            failure.statusCode = 0
            ProblemHelper.showProblem(self, title: "Problem Fetching Child Access Key (Alert Title)".localized, failure: failure )
        } else if result.accessKey == nil || result.accessKey!.isValid() != true {
            ProblemHelper.showProblem(self, title: "Invalid Access Key".localized, message: "Access key missing id or secret".localized, code:0 )
        } else {
            // success!
            AnalyticsHelper.trackResult(.reviewingAccount)
            LogoutHelper.switchUser(result.accessKey!)
        }
    }
    
    @IBAction func toggleChildAccessAction(_ sender: UIButton) {
        let isDisabled = childAccountStatus.disabled!
        let title = isDisabled ? "Enable Child Account (Alert Title)".localized : "Disable Child Account (Alert Title)".localized
        let message = isDisabled ? "Allow your child to use the app".localized : "Log your child out of Mobido and prevent them from using the app".localized
        
        var style:UIAlertActionStyle = .destructive
        if isDisabled {
            style = .default
        }
        AlertHelper.showAlert(self, title: title, message: message, okStyle: style ) {
            let progress = ProgressIndicator(parent: self.view, message: "Toggling Child Account (Progress)".localized )
            self.toggleChildAccessButton.isEnabled = false
            
            let update = UpdateChildAccountAccess()
            update.disable = !isDisabled    // opposite of current state
            MobidoRestClient.instance.updateChildAccountAccess( self.child.uid!, update:update) {
                result in
                
                UIHelper.onMainThread {
                    progress.stop()
                    
                    if ProblemHelper.showProblem(self, title: "Problem Updating Child Account (Problem Title)".localized, failure: result.failure ) {
                        return
                    }
                    
                    AnalyticsHelper.trackResult( update.disable! ? .disabledChildAccount : .enabledChildAccount )
                    self.childAccountStatus?.disabled = update.disable!
                    self.updateToggleButton()
                }
            }
        }
    }
    
    @IBAction func deleteAccountAction(_ sender: UIButton) {
        AlertHelper.showAlert(self, title: "Wipe Child Account (Alert Title)".localized, message:"This will delete ALL your childs chat messages and cards.  It cannot be undone".localized, okStyle: .destructive ) {
            
            let progress = ProgressIndicator(parent: self.view, message: "Wiping Child Account (Progress)".localized )
            self.deleteAccountButton.isEnabled = false
            
            MobidoRestClient.instance.deleteChildAccount( self.child.uid! ) {
                result in
                
                UIHelper.onMainThread {
                    progress.stop()
                    
                    if ProblemHelper.showProblem(self, title: "Problem Wiping Child Account (Problem Title)".localized, failure: result.failure ) {
                        return
                    }
                    
                    AnalyticsHelper.trackResult( .deletedChildAccount )
                    self.showDeleteInProgress()
                }
            }
        }
    }
    
    func showDeleteInProgress() {
        AlertHelper.showOkAlert(self, title: "Wipe Child Account In Progress (Alert Title)".localized, message:"The childs account is being wiped".localized ) {
            self.dismiss(animated: true, completion: nil )
        }
    }
}
