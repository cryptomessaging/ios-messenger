import Foundation

class LogoutHelper {
    
    class func logout(preserveLoginId:Bool) {
        AnalyticsHelper.trackActivity(.loggingOut)
        SyncHelper.clearCaches(exceptAuth:false, exceptLoginId:preserveLoginId, exceptImages:true) {
            LocationService.instance.clear()
            
            UIHelper.onMainThread {
                // WelcomeViewController.showWelcome()
                LandingViewController.showLandingPage()
            }
        }
    }
    
    class func switchUser(_ accessKey:AccessKey) {
        SyncHelper.clearCaches(exceptAuth:true, exceptLoginId:false, exceptImages: true)  { // dont clear auth (we'll overwrite), or images (its ok for us to see them)
            LocationService.instance.clear()
        
            MyUserDefaults.instance.setAccessKey(accessKey);
            //NotificationHelper.signalThreadsUpdated(nil)    // force chat history to update
        
            UIHelper.onMainThread {
                MainViewController.showMain()
            }
        }
    }
}
