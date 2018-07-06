import UIKit
import EasyTipView
import Firebase
import UserNotifications
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    let pushNotificationHandler = PushNotificationHandler.instance
    let pushRegistration = PushRegistration.instance
    
    fileprivate let threadHistory = ThreadHistoryModel.instance
    
    // singleton isn't good enough, iOS needs a strong reference to the service for updates to work
    let locationService = LocationService.instance
    
    // Select main OR welcome storyboards
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // crash reporting (do this first!)
        Fabric.with([Crashlytics.self])
        
        // TEMP: API server fixups
        let prefs = MyUserDefaults.instance
        if !prefs.isDefaultMobidoApiServer() {
            let url = prefs.getMobidoApiServer()
            if url == "https://www.mobido.com" || url == "http://www.mobido.com" || url == "http://c1.mobido.com" {
                prefs.setMobidoAPIServer(nil)   // reset
            }
        }

        ChatDatabase.instance.start()
        
        /* Configure tracker from GoogleService-Info.plist.
        var configureError:NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(String(describing: configureError))")
        
        // Optional: configure GAI options.
        let gai = GAI.sharedInstance()
        //gai?.trackUncaughtExceptions = true  // report uncaught exceptions
        if MyUserDefaults.instance.check(.IsWidgetDeveloper ) {
            gai?.logger.logLevel = GAILogLevel.verbose
            gai?.optOut = true
            print( "Opted out of Google Analytics - demo/test is set to true")
        } else {
            //gai.logger.logLevel = GAILogLevel.Verbose   // TODO remove
            //gai.optOut = false
        }*/
        FirebaseApp.configure()
        let isAnalyticsEnabled = MyUserDefaults.instance.check(.IsWidgetDeveloper ) != true
        AnalyticsConfiguration.shared().setAnalyticsCollectionEnabled(isAnalyticsEnabled)
        
        let vc = MyUserDefaults.instance.getAccessKey() != nil ? MainViewController.create() : LandingViewController.create() //   WelcomeViewController.create()
        let frame = UIScreen.main.bounds
        let window = UIWindow(frame: frame)
        window.backgroundColor = UIColor.white
        window.rootViewController = vc
        window.makeKeyAndVisible()
        
        self.window = window
        
        // started from a user swipe on a notification?
        if let launchOptions = launchOptions {
            if let notificationPayload = launchOptions[UIApplicationLaunchOptionsKey.remoteNotification] as? NSDictionary {
                let userInfo = notificationPayload as! [AnyHashable: Any]
                if let tid = PushNotificationHandler.instance.getMessageTid( userInfo ) {
                    DebugLogger.instance.append( "Swiped from notification for tid \(tid)" )
                    NotificationHelper.signalShowChat( tid );
                }
            }
        }
        
        // register to handle notifications
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        return true
    }
    
    //
    // MARK: Deep linking (handle invites)
    //
    
    // format: mobido:rsvp/43522
    func application(_ application: UIApplication, open url: URL, options:[UIApplicationOpenURLOptionsKey: Any]) -> Bool {
        
        let i = url.scheme!.endIndex
        let path = url.absoluteString.substring(from: i)
        let params = path.components(separatedBy: "/")
        if params[0] == ":rsvp" && params.count > 1 {
            if let vc = UIHelper.topVC() {
                // make sure we have an account
                let prefs = MyUserDefaults.instance
                let rsvpSecret = params[1]
                if prefs.getAccessKey() == nil {
                    AlertHelper.showOkAlert(vc, title: "Please sign in or create an account (Title)".localized, message: "You must be signed into Mobido before you can accept an RSVP".localized, okAction: nil)
                    prefs.set(.PENDING_RSVP_SECRET, withValue: rsvpSecret)
                } else {
                    RsvpHelper.showRsvpDialog(vc, secret: rsvpSecret )
                }
            }
        }
        
        return true
    }
    
    //
    // MARK: Notifications registration
    //
    
    func application( _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data ) {
        PushRegistration.instance.registerDeviceToken( deviceToken:deviceToken )
    }
    
    func application( _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error ) {
        PushRegistration.instance.onDidFailToRegisterForRemoteNotificationsWithError( error )
    }
    
    //
    // MARK: Starting/stopping app
    //
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
        // handle badge - if there's a number it means we got a message, so signal for screens to update
        let app = UIApplication.shared
        let badgeNumber = app.applicationIconBadgeNumber
        if badgeNumber > 0 {
            app.applicationIconBadgeNumber = 0
            
            // ugh, the user tapped the app icon, and NOT the notification
            NotificationHelper.signal(.blindApn)
            
            // make sure our thread history is up to date (ugh2, going to server...)
            threadHistory.load( .server, statusCallback: nil, completion: nil )
        }
        
        // EasyTipView setup
        var preferences = EasyTipView.Preferences()
        preferences.drawing.font = UIFont.systemFont(ofSize: 20)
        preferences.drawing.foregroundColor = UIColor.white
        preferences.drawing.backgroundColor = UIConstants.ToolTipBackground
        preferences.drawing.arrowPosition = EasyTipView.ArrowPosition.top
        preferences.drawing.textAlignment = .left
        EasyTipView.globalPreferences = preferences
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough
        // application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of
        // applicationWillTerminate: when the user quits.
    }
    
    //
    // MARK: Incoming notifications
    //
    
    func application( _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        PushNotificationHandler.instance.onDidReceiveRemoteNotification( userInfo, fetchCompletionHandler: nil )
    }
    
    // this should get called when app is backgrounded, suspended, or even not started
    // NOTE: if the app has been force killed, this WILL NOT be called
    func application( _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler handler: @escaping (UIBackgroundFetchResult) -> Void) {

        let pushHandler = PushNotificationHandler.instance
        pushHandler.onDidReceiveRemoteNotification( userInfo, fetchCompletionHandler: handler )
        
        if application.applicationState == .inactive || application.applicationState == .background  {
            // opened from a push notification when the app was in background
            if let tid = pushHandler.getMessageTid( userInfo ) {
                NotificationHelper.signalShowChat( tid );
            }
        }
    }
    
    // This method will be called when app received push notifications in foreground
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        let userInfo = notification.request.content.userInfo
        PushNotificationHandler.instance.onDidReceiveRemoteNotification( userInfo ) {
            result in
            
            if let tid = PushNotificationHandler.instance.getMessageTid( userInfo ) {
                let currentTid = GroupThreadViewGlobals.currentTid
                if tid == currentTid {
                    // user is currently chatting on this thread, so silence notification
                    completionHandler([])
                    return
                }
            }
            
            // user is outside of chat, or in another chat, so pop up incoming message
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // TODO any need to PushNotificationHandler.instance.onDidReceiveRemoteNotification( userInfo )?
        let userInfo = response.notification.request.content.userInfo
        let pushHandler = PushNotificationHandler.instance
        if let tid = pushHandler.getMessageTid( userInfo ) {
            NotificationHelper.signalShowChat( tid );
        }
        completionHandler()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        ChatDatabase.instance.stop()
    }
    
    //
    // MARK: Unused application callbacks
    //
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        //print( "Entering foreground!" )
    }
}
