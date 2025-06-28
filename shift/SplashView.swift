import SwiftUI

// Define destinations for navigation stack
enum AuthDestination: Hashable {
    case login
    // Add case signUp if needed for value-based navigation
}

struct SplashView: View {
    @Namespace private var animationNamespace // Namespace for the animation
    @State private var isActive = false // Controls splash animation visibility
    @State private var showAuthUI = false // Controls auth buttons visibility
    @State private var didCompleteSignUp = false // Gets set by SignUpView
    @State private var didCompleteLogin = false // State for login completion
    @State private var needsSignUp = false // Controls presentation of SignUpView modal/sheet style
    @State private var showMainApp = false // Controls showing MainTabView
    @State private var isCheckingAuth = true // Track if we're checking authentication
    @EnvironmentObject var userSession: FirebaseUserSession // Access to authentication state
    @Environment(\.colorScheme) var colorScheme // Add environment variable for color scheme
    // @State private var size = 0.8 // No longer needed for this animation
    // @State private var opacity = 0.5 // No longer needed for this animation

    var body: some View {
        // ENHANCED LOGGING: Track every state evaluation
        let _ = print("🎬 SplashView body: isLoggedIn=\(userSession.isLoggedIn), isCheckingAuth=\(isCheckingAuth), showAuthUI=\(showAuthUI)")
        let _ = print("🎬 SplashView body: Thread=MAIN")
        
        // CRITICAL: Monitor when isCheckingAuth should change
        let _ = userSession.isLoggedIn ? print("🎬 SplashView: User is logged in, should stop checking auth") : print("🎬 SplashView: User not logged in")
        let _ = !userSession.isLoading ? print("🎬 SplashView: User session not loading, should stop checking auth") : print("🎬 SplashView: User session still loading")
        
        // FIXED: Simplified logic to prevent race conditions
        if userSession.isLoggedIn {
            // User is authenticated - show main app immediately
            let _ = print("🎯 SplashView: Showing MainTabView for authenticated user")
            MainTabView(showSubscriptionModalInitially: didCompleteSignUp)
                .transition(.opacity)
                .onAppear {
                    print("🎯 MainTabView appeared - user is logged in")
                    print("🎯 MainTabView onAppear: Thread=MAIN")
                    
                    // CRITICAL: Stop checking auth when main app appears
                    if isCheckingAuth {
                        print("🎬 CRITICAL: Stopping auth check - main app appeared")
                        isCheckingAuth = false
                    }
                }
        } else if isCheckingAuth {
            // Show loading state while checking authentication
            let _ = print("🔍 SplashView: Showing loading screen")
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .onTapGesture {
                            print("🔍 LOGO TAPPED during loading - this should work if UI is responsive")
                        }
                    
                    ProgressView()
                        .scaleEffect(1.2)
                        .onTapGesture {
                            print("🔍 PROGRESS VIEW TAPPED - this should work if UI is responsive")
                        }
                    
                    Text("Checking authentication...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            print("🔍 TEXT TAPPED during loading - this should work if UI is responsive")
                        }
                }
            }
            .onAppear {
                print("🔍 Showing loading screen - checking auth...")
                print("🔍 Loading screen onAppear: Thread=MAIN")
                
                // CRITICAL: Add timeout for checking auth to prevent infinite loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if isCheckingAuth && !userSession.isLoggedIn {
                        print("🔍 AUTH CHECK TIMEOUT - forcing to show auth UI")
                        isCheckingAuth = false
                    }
                }
            }
            .onChange(of: userSession.isLoggedIn) { _, newValue in
                print("🔍 Loading screen: userSession.isLoggedIn changed to \(newValue)")
                if newValue {
                    print("🔍 User logged in during loading - should transition to main app")
                }
            }
            .onChange(of: userSession.isLoading) { _, newValue in
                print("🔍 Loading screen: userSession.isLoading changed to \(newValue)")
                if !newValue && !userSession.isLoggedIn {
                    print("🔍 CRITICAL: User session finished loading but not logged in - stopping auth check")
                    isCheckingAuth = false
                }
            }
        } else {
            // User not authenticated - show auth UI
            let _ = print("🔑 SplashView: Showing auth UI")
            NavigationStack {
                ZStack { // Main container
                    // Use adaptive system background
                    Color(.systemBackground).ignoresSafeArea()
                        .onTapGesture {
                            print("🔑 BACKGROUND TAPPED - UI should be responsive")
                        }

                    // Logo - Always present, position changes
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .matchedGeometryEffect(id: "logo", in: animationNamespace)
                        // Align based on state within the ZStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAuthUI ? .top : .center)
                        .padding(.top, showAuthUI ? 60 : 0) // Add padding when active to push it down
                        .onTapGesture {
                            print("🔑 LOGO TAPPED in auth screen - UI should be responsive")
                        }

                    // Auth Screen Elements (Title, Subtitle, Buttons)
                    VStack(spacing: 16) {
                        // Placeholder Spacer to push content below the logo when it moves to the top
                        // Adjust height based on logo size and padding
                        Spacer().frame(height: showAuthUI ? 200 : 0) 

                        Text("Shift")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.primary)
                            .onTapGesture {
                                print("🔑 TITLE TAPPED - UI should be responsive")
                            }

                        Text("See Singles Where You\'re At")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 40)
                            .onTapGesture {
                                print("🔑 SUBTITLE TAPPED - UI should be responsive")
                            }

                        Spacer() // Pushes buttons to the bottom

                        // Sign Up Button (now just sets state)
                         Button {
                             print("🔑 SIGN UP BUTTON TAPPED - Starting signup flow")
                             print("🔑 SIGN UP: Thread=MAIN")
                             Haptics.lightImpact() // Add haptic
                             needsSignUp = true // Trigger navigationDestination below
                             print("🔑 SIGN UP: needsSignUp set to true")
                         } label: {
                             Text("SIGN UP")
                                 .font(.headline)
                                 .foregroundColor(.white)
                                 .frame(maxWidth: .infinity)
                                 .padding()
                                 .background(Color.blue)
                                 .cornerRadius(10)
                         }
                        .padding(.horizontal, 40)
                        .onAppear {
                            print("🔑 SIGN UP BUTTON appeared")
                        }

                        // Login Link (use value-based navigation)
                        NavigationLink(value: AuthDestination.login) {
                            Text("ALREADY HAVE AN ACCOUNT?")
                                .font(.footnote)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary, lineWidth: 1)
                                )
                        }
                        // Add haptic on tap gesture for NavigationLink label
                        .simultaneousGesture(TapGesture().onEnded { 
                            print("🔑 LOGIN LINK TAPPED - Starting login flow")
                            print("🔑 LOGIN: Thread=MAIN")
                            Haptics.lightImpact() 
                        })
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                        .onAppear {
                            print("🔑 LOGIN LINK appeared")
                        }

                        Spacer().frame(height: 40) // Bottom padding
                    }
                    .padding(.top) // Overall padding for the VStack content
                    // Fade in the auth elements only when active
                    .opacity(showAuthUI ? 1 : 0)
                    // Add a slight delay to the fade-in animation if desired
                    .animation(.easeIn.delay(0.2), value: showAuthUI) 

                }
                .onAppear {
                    print("🔑 Auth UI container appeared")
                    startSplashAnimation()
                }
                // Watch for sign-up completion
                .onChange(of: didCompleteSignUp) { _, newValue in
                     if newValue {
                         print("✅ Sign up completed")
                     }
                 }
                 // Add onChange for login completion
                 .onChange(of: didCompleteLogin) { _, newValue in
                      if newValue {
                          print("✅ Login completed")
                      }
                  }
                // Navigation Destination for Sign Up (presented programmatically)
                .navigationDestination(isPresented: $needsSignUp) { 
                    SignUpView(didCompleteSignUp: $didCompleteSignUp)
                        .onAppear {
                            print("🔑 SignUpView appeared")
                        }
                }
                // Navigation Destination for Login (based on value)
                .navigationDestination(for: AuthDestination.self) { destination in
                    switch destination {
                        case .login:
                            LoginView(didCompleteLogin: $didCompleteLogin, needsSignUp: $needsSignUp)
                                .onAppear {
                                    print("🔑 LoginView appeared")
                                }
                    }
                }
            }
            .onAppear {
                print("📱 Showing auth UI - user not authenticated")
            }
        }
    }
    
    // MARK: - Helper Functions
    private func startSplashAnimation() {
        // Simplified - just show auth UI after brief delay
        print("🎬 Starting auth UI animation...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎬 Animation delay completed, showing auth UI")
            withAnimation(.easeInOut(duration: 0.7)) {
                print("🎬 Setting isActive=true, showAuthUI=true")
                self.isActive = true
                self.showAuthUI = true
            }
        }
    }
}

// Keep the original ContentView struct in case you need it later
// struct ContentView: View { ... }

#Preview {
    SplashView()
} 