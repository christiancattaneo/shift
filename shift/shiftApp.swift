//
//  shiftApp.swift
//  shift
//
//  Created by Christian Cattaneo on 4/21/25.
//

import SwiftUI
import Firebase
import UserNotifications
import os

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 App launching: Thread=MAIN")
        
        // Configure Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
        
        // Validate resources
        validateAppResources()
        
        // Print memory info
        printMemoryUsage()
        
        // Image sync removed - using UUID-based system now
        
        // Setup push notifications
        setupPushNotifications(application)
        
        return true
    }
    
    // Handle Firebase URL schemes for authentication and email links
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🔗 App opened with URL: \(url)")
        
        // Handle email link authentication
        if FirebaseUserSession.shared.isSignInLink(url.absoluteString) {
            print("✅ Detected email link authentication URL")
            handleEmailLink(url: url)
            return true
        }
        
        return true
    }
    
    // Handle universal links for email authentication
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        print("🔗 App opened with universal link: \(userActivity.webpageURL?.absoluteString ?? "unknown")")
        
        if let url = userActivity.webpageURL {
            // Handle email link authentication
            if FirebaseUserSession.shared.isSignInLink(url.absoluteString) {
                print("✅ Detected email link authentication via universal link")
                handleEmailLink(url: url)
                return true
            }
        }
        
        return false
    }
    
    private func handleEmailLink(url: URL) {
        print("🔐 Processing email link: \(url)")
        
        // Check if we have a stored email
        if let email = FirebaseUserSession.shared.getPendingEmailLink() {
            print("📧 Found stored email for link: \(email)")
            
            // Complete sign-in with email link
            FirebaseUserSession.shared.signInWithEmailLink(email: email, link: url.absoluteString) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Email link authentication successful")
                        // Post notification to update UI if needed
                        NotificationCenter.default.post(name: NSNotification.Name("EmailLinkSignInSuccess"), object: nil)
                    } else {
                        print("❌ Email link authentication failed: \(error ?? "unknown error")")
                        NotificationCenter.default.post(name: NSNotification.Name("EmailLinkSignInError"), object: error)
                    }
                }
            }
        } else {
            print("⚠️ No stored email found for email link")
            // You might want to prompt the user to enter their email
            NotificationCenter.default.post(name: NSNotification.Name("EmailLinkNeedsEmail"), object: url.absoluteString)
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        print("🔄 App became active")
        printMemoryUsage()
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        print("⏸️ App will resign active")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("📱 App entered background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("📱 App will enter foreground")
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        print("🛑 App will terminate")
    }
    
    // Validate critical app resources
    private func validateAppResources() {
        print("🔍 Validating app resources...")
        
        // Check for GoogleService-Info.plist
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") == nil {
            print("⚠️ GoogleService-Info.plist not found - Firebase may not work properly")
        } else {
            print("✅ GoogleService-Info.plist found")
        }
        
        // Check for app icon (iOS handles app icons differently)  
        if let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIconDict = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIconDict["CFBundleIconFiles"] as? [String], !iconFiles.isEmpty {
            print("✅ App icon configured")
        } else {
            print("⚠️ App icon configuration not found - this is normal during development")
        }
        
        // Validate data directory (if needed)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if !documentsPath.isEmpty {
            print("✅ Documents directory accessible")
        }
    }
    
    private func printMemoryUsage() {
        // Simple memory usage tracking
        let processInfo = ProcessInfo.processInfo
        print("💾 Process Info: Physical Memory: \(processInfo.physicalMemory / 1024 / 1024) MB")
        print("💾 Active Processors: \(processInfo.activeProcessorCount)")
        print("💾 System Uptime: \(String(format: "%.1f", processInfo.systemUptime)) seconds")
    }
    
    // MARK: - Push Notifications Setup
    
    private func setupPushNotifications(_ application: UIApplication) {
        print("🔔 Setting up push notifications...")
        
        // Set delegates
        UNUserNotificationCenter.current().delegate = self
        // TODO: Add FirebaseMessaging package and uncomment:
        // Messaging.messaging().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔔 Notification permission granted: \(granted)")
            if let error = error {
                print("❌ Error requesting notifications: \(error)")
            }
        }
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
    }
    
    // MARK: - Remote Notification Registration
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("✅ Registered for remote notifications")
        // TODO: Add FirebaseMessaging package and uncomment:
        // Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        print("🔔 Notification tapped: \(userInfo)")
        
        // Handle different notification types
        if let notificationType = userInfo["type"] as? String {
            handleNotificationAction(type: notificationType, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    // MARK: - MessagingDelegate
    // TODO: Add FirebaseMessaging package and uncomment this section:
    /*
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔔 FCM Token: \(fcmToken ?? "nil")")
        
        // Store FCM token for the current user
        if let fcmToken = fcmToken {
            FirebaseUserSession.shared.updateFCMToken(fcmToken)
        }
    }
    */
    
    // MARK: - Notification Handling
    
    private func handleNotificationAction(type: String, userInfo: [AnyHashable: Any]) {
        switch type {
        case "message":
            // Navigate to messages
            if let senderId = userInfo["senderId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenChat"),
                    object: nil,
                    userInfo: ["senderId": senderId]
                )
            }
            
        case "like":
            // Navigate to likes/matches
            NotificationCenter.default.post(name: NSNotification.Name("OpenLikes"), object: nil)
            
        case "event":
            // Navigate to event
            if let eventId = userInfo["eventId"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenEvent"),
                    object: nil,
                    userInfo: ["eventId": eventId]
                )
            }
            
        default:
            print("Unknown notification type: \(type)")
        }
    }
}

@main
struct shiftApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = FirebaseUserSession.shared
    
    init() {
        // Firebase is already configured in AppDelegate
        // No need to configure again here
        
        // Background tasks removed - using UUID-based system now
        
        // Preload events and members for better UX
        Task {
            print("🔄 Preloading events and members...")
            let eventsService = FirebaseEventsService()
            let membersService = FirebaseMembersService.shared
            
            // Start both requests in parallel
            async let _ = eventsService.fetchEvents()
            async let _ = membersService.fetchMembers()
            
            print("✅ Preloading initiated")
        }
    }
    
    var body: some Scene {
        print("🚀 App body: Thread=MAIN")
        
        return WindowGroup {
            SplashView()
                .environmentObject(userSession)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Handle app becoming active
                    print("📱 App became active (notification)")
                    print("📱 Notification: Thread=MAIN")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    print("📱 App will resign active (notification)")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    print("📱 App entered background (notification)")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    print("📱 App will enter foreground (notification)")
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    print("📱 App will terminate (notification)")
                }
                .onAppear {
                    print("🚀 SplashView onAppear from App")
                    print("🚀 SplashView onAppear: Thread=MAIN")
                }
        }
    }
}
