//
//  AskBirthdayViewController.swift
//  Messenger
//
//  Created by Mike Prince on 10/11/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import UIKit

class AskBirthdayViewController : UIViewController {
    @IBOutlet weak var datePicker: UIDatePicker!
    var nextButton:UIBarButtonItem!
    let TWO_YEARS_IN_SECONDS = Double(60 * 60 * 24 * 365 * 2)
    
    class func showAskBirthday(_ nav:UINavigationController) {
        let vc = AskBirthdayViewController(nibName: "AskBirthdayView", bundle: nil)
        nav.pushViewController( vc, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup navigation bar
        edgesForExtendedLayout = UIRectEdge()
        nextButton = UIBarButtonItem(title: "Next".localized, style: .plain, target: self, action: #selector(nextButtonAction))
        navigationItem.rightBarButtonItem = nextButton
        navigationItem.title = "Age Check".localized
        
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged )
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        verifyDate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AnalyticsHelper.trackScreen( .askBirthday, vc:self )
    }
    
    func dateChanged() {
        let ymd = TimeHelper.asYmd( datePicker.date )
        MyUserDefaults.instance.set( .SIGNUP_BIRTHDAY, withValue: ymd )
        
        verifyDate()
    }
    
    func verifyDate() {
        nextButton.isEnabled = TimeHelper.calculateAge(datePicker.date) >= 2
    }
    
    func nextButtonAction(_ sender: UIBarButtonItem) {
        if TimeHelper.calculateAge(datePicker.date) < 13 {
            DirectNoticeFormViewController.showDirectNoticeForm(self.navigationController!)
        } else if UIConstants.automaticAnonymousAccount {
            QuickstartHelper.createAnonymousAccount(self)
        } else if UIConstants.offerQuickstart {
            QuickstartViewController.pushQuickstart(self.navigationController!)
        } else {
            SignupViewController.showSignup(self)
        }
    }
}
