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
        // FIXED: Simplified logic to prevent race conditions
        if userSession.isLoggedIn {
            // User is authenticated - show main app immediately
            MainTabView(showSubscriptionModalInitially: didCompleteSignUp)
                .transition(.opacity)
                .onAppear {
                    print("🎯 MainTabView appeared - user is logged in")
                }
        } else if isCheckingAuth {
            // Show loading state while checking authentication
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 20) {
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                    
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Checking authentication...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                print("🔍 Showing loading screen - checking auth...")
            }
        } else {
            // User not authenticated - show auth UI
            NavigationStack {
                ZStack { // Main container
                    // Use adaptive system background
                    Color(.systemBackground).ignoresSafeArea()

                    // Logo - Always present, position changes
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        .matchedGeometryEffect(id: "logo", in: animationNamespace)
                        // Align based on state within the ZStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAuthUI ? .top : .center)
                        .padding(.top, showAuthUI ? 60 : 0) // Add padding when active to push it down

                    // Auth Screen Elements (Title, Subtitle, Buttons)
                    VStack(spacing: 16) {
                        // Placeholder Spacer to push content below the logo when it moves to the top
                        // Adjust height based on logo size and padding
                        Spacer().frame(height: showAuthUI ? 200 : 0) 

                        Text("Shift")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.primary)

                        Text("See Singles Where You\'re At")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 40)

                        Spacer() // Pushes buttons to the bottom

                        // Sign Up Button (now just sets state)
                         Button {
                             Haptics.lightImpact() // Add haptic
                             needsSignUp = true // Trigger navigationDestination below
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
                        .simultaneousGesture(TapGesture().onEnded { Haptics.lightImpact() })
                        .padding(.horizontal, 40)
                        .padding(.top, 10)

                        Spacer().frame(height: 40) // Bottom padding
                    }
                    .padding(.top) // Overall padding for the VStack content
                    // Fade in the auth elements only when active
                    .opacity(showAuthUI ? 1 : 0)
                    // Add a slight delay to the fade-in animation if desired
                    .animation(.easeIn.delay(0.2), value: showAuthUI) 

                }
                .onAppear {
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
                }
                // Navigation Destination for Login (based on value)
                .navigationDestination(for: AuthDestination.self) { destination in
                    switch destination {
                        case .login:
                            LoginView(didCompleteLogin: $didCompleteLogin, needsSignUp: $needsSignUp)
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
        print("🎬 Starting auth UI...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.7)) {
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