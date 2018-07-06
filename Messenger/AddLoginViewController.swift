//
//  AddLoginViewController.swift
//  Messenger
//
//  Created by Mike Prince on 2/19/17.
//  Copyright © 2017 Mike Prince. All rights reserved.
//

import Foundation

class AddLoginViewController : UIViewController {
    @IBOutlet weak var loginField: UITextField!
    var createButton:UIBarButtonItem?
    
    class func showAddLogin(_ nav:UINavigationController) {
        let vc = AddLoginViewController(nibName: "AddLoginView", bundle: nil)
        nav.pushViewController(vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        edgesForExtendedLayout = UIRectEdge()
        createButton = UIBarButtonItem(title: "Create (Button)".localized, style: .plain, target: self, action: #selector(createButtonAction))
        navigationItem.rightBarButtonItem = createButton
        navigationItem.title = "Add Login (Title)".localized
        
        createButton?.isEnabled = false
        //loginField.delegate = self
        loginField.addTarget(self, action: #selector(textFieldDidChange), for: UIControlEvents.editingChanged)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .addLogin, vc:self )
    }
    
    func textFieldDidChange(_ textField:UITextField) {
        createButton?.isEnabled = StringHelper.clean( loginField.text ) != nil
    }
    
    func createButtonAction(_ sender: UIBarButtonItem) {
        let id = StringHelper.clean( loginField.text )!
        let authority = StringHelper.isValidEmail( id ) ? "email" : "username"
        let login = Login(authority: authority,id:id)

        let progress = ProgressIndicator(parent: view, message: "Creating Login (Progress)".localized)
        createButton?.isEnabled = false
        MobidoRestClient.instance.createLogin(login) {
            result -> Void in
            UIHelper.onMainThread {
                progress.stop()
                self.createButton?.isEnabled = true
                
                if !ProblemHelper.showProblem(self, title: "Problem Creating Login (Title)".localized, failure: result.failure ) {
                    _ = self.navigationController?.popViewController( animated: true )
                }
            }
        }
    }
}
