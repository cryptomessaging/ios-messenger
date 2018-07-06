//
//  AlertHelper.swift
//  Messenger
//
//  Created by Mike Prince on 11/8/16.
//  Copyright © 2016 Mike Prince. All rights reserved.
//

import Foundation

class AlertHelper {
    class func showAlert(_ vc:UIViewController, title:String, message:String, okStyle: UIAlertActionStyle, okAction:(()->Void)? ) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localized, style: okStyle ) {
            action in
            
            okAction?()
        }
        alert.addAction( okAction )
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil ))
        vc.present(alert, animated: true, completion: nil )
    }
    
    class func showOkAlert( _ vc:UIViewController, title:String, message:String, okAction:(()->Void)? ) {
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK".localized, style: .default ) {
            action in
            
            okAction?()
        }
        alert.addAction( okAction )
        vc.present(alert, animated: true, completion: nil )
    }
}
