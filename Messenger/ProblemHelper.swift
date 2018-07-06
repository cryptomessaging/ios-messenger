import UIKit

class ProblemHelper {
    
    @discardableResult class func showProblem( _ vc:UIViewController?, title:String, failure:Failure?) -> Bool {
        if let fail = failure {
            let message = fail.message!
            let code = fail.statusCode == nil ? 500 : fail.statusCode!
            showProblem(vc, title:title, message:message, code:code, completion:nil)
            return true
        } else {
            return false
        }
    }
    
    class func showProblem( _ vc:UIViewController?, title:String, failure:Failure, completion:@escaping ()->Void ) {
        showProblem(vc, title:title, message:failure.message!, code:failure.statusCode, completion:completion )
    }
    
    class func showProblem( _ vc:UIViewController?, title:String, message:String, code:Int? = 0, completion:(()->Void)? = nil ) {
        
        // make sure we are on the main thread
        if Thread.isMainThread == false {
            UIHelper.onMainThread {
                showProblem( vc, title:title, message:message, code:code, completion:completion )
            }
            return
        }
        
        guard let vc = UIHelper.topVC() else {
            print( "Failed to get VC, not showing problem :(")
            return
        }
        
        let alert = UIAlertController(title:title, message:message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: UIAlertActionStyle.default, handler: { UIAlertAction -> Void in
            if code == 401 {
                // if we find ourselves unauthorized, then force another login
                LogoutHelper.logout(preserveLoginId: true)
            } else {
                completion?()
            }
        } ))
        vc.present(alert, animated: true, completion: nil )
        AnalyticsHelper.trackPopover( .problem, vc:alert )
        DebugLogger.instance.append( "Showing Problem: \(title) - \(message) (\(String(describing: code)))" )
    }
}
