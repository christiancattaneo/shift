//
//  shiftApp.swift
//  shift
//
//  Created by Christian Cattaneo on 4/21/25.
//

import SwiftUI
import Firebase

@main
struct shiftApp: App {
    @StateObject private var userSession = FirebaseUserSession.shared
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(userSession)
                .onAppear {
                    userSession.loadSavedUser()
                }
        }
    }
}
