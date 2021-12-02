import UIKit
import UserNotifications
import CleverTapSDK
import CTNotificationService
//import CTC

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CleverTapInAppNotificationDelegate, CleverTapSyncDelegate, CleverTapFeatureFlagsDelegate, CleverTapProductConfigDelegate {
    
    var window: UIWindow?
    var orientationLock = UIInterfaceOrientationMask.portrait
    var innstance: CleverTap?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Override point for customization after application launch.
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        } else {
            // Fallback on earlier versions
        };
        
//        CleverTap.setCredentialsWithAccountID("4RW-Z6Z-485Z", token: "161-024", region: "sk1-staging-2")
//        CleverTap.setCredentialsWithAccountID("TEST-Z9R-486-4W5Z", andToken: "TEST-6b4-2c1")
        
//        CleverTap.setCredentialsWithAccountID("RWW-WWW-WW4Z", token: "000-002", region: "sk1")
        
        
//        CleverTap.sharedInstance()?.enableDeviceNetworkInfoReporting(false)
//        CleverTap.setCredentialsWithAccountID("W9R-486-4W5Z", andToken: "6b4-2c0")
        
        CleverTap.setDebugLevel(1)
//        CleverTap.autoIntegrate()
        
        CleverTap.setCredentialsWithAccountID("W9R-486-4W5Z", token: "6b4-2c0", proxyDomain: "analytics.sdktesting.xyz", spikyProxyDomain: "analyticst.sdktesting.xyz")
//
        let congig = CleverTapInstanceConfig(accountId: "W9R-486-4W5Z", accountToken: "6b4-2c0", proxyDomain: "analytics.sdktesting.xyz", spikyProxyDomain: "analyticst.sdktesting.xyz")
        congig.logLevel = .debug
        innstance = CleverTap.instance(with: congig)
//        innstance?.productConfig.delegate = self;
//
//        innstance?.productConfig.fetchAndActivate()

        innstance?.recordEvent("testEvent", withProps: ["fav": 23])
//        innstance?.recordChargedEvent(withDetails: [:], andItems: [])
        
//        innstance?.profileIncrementValue(by: 50, forKey: "score")
        
//        innstance?.profileDecrementValue(by: 10, forKey: "score")
//        innstance?.onUserLogin([:])
//        innstance?.recordScreenView("AppDelegate screen")
        
//        CleverTap.sharedInstance()?.setInAppNotificationDelegate(self)
        CleverTap.sharedInstance()?.productConfig.delegate = self;
        CleverTap.sharedInstance()?.featureFlags.delegate = self;
        
        
        registerPush()

        return true
    }
    
    private func registerPush() {
        // request permissions
        if #available(iOS 10.0, *) {
            if #available(iOS 12.0, *) {
                UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert, .badge, .provisional]) {
                    (granted, error) in
                    if (granted) {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        } else {
            // Fallback on earlier versions
        }
    }
    
    func profileDidInitialize(_ CleverTapID: String!, forAccountId accountId: String!) {
        print(CleverTapID ?? "unknown")
        print(accountId ?? "unknown")
    }
    
    func ctFeatureFlagsUpdated() {
        NSLog("CleverTap feature flags updated")
        DispatchQueue.global(qos: .background).async {
        let ffFoo = CleverTap.sharedInstance()?.featureFlags.get("test_atul_bool", withDefaultValue:false)
        print(ffFoo!)
        let ffDiscount = CleverTap.sharedInstance()?.featureFlags.get("is_veg", withDefaultValue:false)
        print(ffDiscount!)
        }
    }
    
    func ctProductConfigInitialized() {
        NSLog("CleverTap Product Config updated")
        let vall = CleverTap.sharedInstance()?.productConfig.get("appColor")
        print(vall)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("%@: failed to register for remote notifications: %@", self.description, error.localizedDescription)
    }
//
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        CleverTap.sharedInstance()?.enableDeviceNetworkInfoReporting((1 != 0))
//        CleverTap.sharedInstance()?.recordEvent("Content Started")
        
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
//        CleverTap.sharedInstance()?.setPushToken(deviceToken)
        innstance?.setPushToken(deviceToken)
        NSLog("%@: registered for remote notifications: %@", self.description, deviceToken.description)
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
        innstance?.recordNotificationViewedEvent(withData: response.notification.request.content.userInfo)
//        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: response.notification.request.content.userInfo)

        NSLog("%@: did receive notification response: %@", self.description, response.notification.request.content.userInfo)
        completionHandler()
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NSLog("%@: will present notification: %@", self.description, notification.request.content.userInfo)
        completionHandler([.badge, .sound, .alert])
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NSLog("%@: did receive remote notification completionhandler: %@", self.description, userInfo)
        completionHandler(UIBackgroundFetchResult.noData)
    }
    
    func application(application: UIApplication, openURL url: NSURL,
                             sourceApplication: String?, annotation: AnyObject) -> Bool {
        DispatchQueue.global(qos: .background).async {
        CleverTap.sharedInstance()?.handleOpen(url as URL, sourceApplication: sourceApplication)
        }
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        DispatchQueue.global(qos: .background).async {
        CleverTap.sharedInstance()?.handleOpen(url, sourceApplication: nil)
        }
        return true
    }
    
    func open(_ url: URL, options: [String : Any] = [:],
              completionHandler completion: ((Bool) -> Swift.Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
        CleverTap.sharedInstance()?.handleOpen(url, sourceApplication: nil)
        }
        completion?(false)
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func inAppNotificationButtonTapped(withCustomExtras customExtras: [AnyHashable : Any]!) {
        print("In-App Button Tapped with custom extras:%@", customExtras ?? "");
        let dict: NSDictionary = customExtras as NSDictionary
        print("In-App Button Tapped with custom extras:", dict.description);
    }
    
    func shouldShowInAppNotification(withExtras extras: [AnyHashable : Any]!) -> Bool {
        NSLog("shouldShowNotificationwithExtras called: %@", extras ?? "")
        return true;
    }
    
    func inAppNotificationDismissed(withExtras extras: [AnyHashable : Any]!, andActionExtras actionExtras: [AnyHashable : Any]!) {
        NSLog("inAppNotificationDismissed called withExtras: %@ actionExtras: %@", extras ?? "", actionExtras ?? "")
    }
    
    //    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    //        return self.orientationLock
    //    }
    //
    //    struct AppUtility {
    //        static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
    //            if let delegate = UIApplication.shared.delegate as? AppDelegate {
    //                delegate.orientationLock = orientation
    //            }
    //        }
    //
    //        static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
    //            self.lockOrientation(orientation)
    //            UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
    //        }
    //    }
    
//    didreceive
}
