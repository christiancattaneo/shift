//
//  shiftApp.swift
//  shift
//
//  Created by Christian Cattaneo on 4/21/25.
//

import SwiftUI
import Firebase

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
        
        // Validate resources
        validateAppResources()
        
        return true
    }
    
    // Handle Firebase URL schemes for authentication
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // This can be used for Firebase Auth URL handling if needed
        return true
    }
    
    // Validate critical app resources
    private func validateAppResources() {
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
}

@main
struct shiftApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var userSession = FirebaseUserSession.shared
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(userSession)
                .onAppear {
                    userSession.loadSavedUser()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Handle app becoming active
                    print("📱 App became active")
                }
        }
    }
}
