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
    @Environment(\.colorScheme) var colorScheme // Add environment variable for color scheme
    // @State private var size = 0.8 // No longer needed for this animation
    // @State private var opacity = 0.5 // No longer needed for this animation

    var body: some View {
        // Determine the root view based on state
        if showMainApp {
            // User just signed up OR logged in 
            // Show subscription modal only if they just signed up
            MainTabView(showSubscriptionModalInitially: didCompleteSignUp)
                .transition(.opacity) 
        } else {
            // Use NavigationStack for modern navigation APIs
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
                    // Start splash animation timer only once
                    guard !isActive else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.7)) {
                            self.isActive = true // Mark splash animation phase done
                            self.showAuthUI = true // Show the auth UI elements
                        }
                    }
                }
                // Watch for sign-up completion
                .onChange(of: didCompleteSignUp) { _, newValue in
                     if newValue {
                         // Trigger transition to the main app view
                         withAnimation { 
                             self.showMainApp = true
                         }
                     }
                 }
                 // Add onChange for login completion
                 .onChange(of: didCompleteLogin) { _, newValue in
                      if newValue {
                          withAnimation { self.showMainApp = true }
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
        }
    }
}

// Keep the original ContentView struct in case you need it later
// struct ContentView: View { ... }

#Preview {
    SplashView()
} 