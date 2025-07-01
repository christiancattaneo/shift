//
//  shiftApp.swift
//  shift
//
//  Created by Christian Cattaneo on 4/21/25.
//

import SwiftUI
import Firebase
import os

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("🚀 App launching: Thread=MAIN")
        
        // Configure Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
        
        // Validate resources
        validateAppResources()
        
        // Print memory info
        printMemoryUsage()
        
        // Start background image sync for scalability
        Task {
            await FirebaseServices.shared.syncExistingUserImages()
        }
        
        return true
    }
    
    // Handle Firebase URL schemes for authentication
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("🔗 App opened with URL: \(url)")
        // This can be used for Firebase Auth URL handling if needed
        return true
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
}

@main
struct shiftApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = FirebaseUserSession.shared
    
    init() {
        // Firebase is already configured in AppDelegate
        // No need to configure again here
        
        // Start background tasks for scalability
        Task {
            await FirebaseServices.shared.syncExistingUserImages()
        }
        
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
