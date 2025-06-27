import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Binding to signal completion
    @Binding var didCompleteLogin: Bool
    
    // Binding to potentially switch back to Sign Up view
    @Binding var needsSignUp: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView { // Use ScrollView to prevent overflow on smaller devices
                VStack(spacing: 25) {
                    // Logo (Similar to SignUp)
                    HStack {
                        Image("shiftlogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        Text("Shift")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 30)
                    .padding(.top, 50) // Add padding at the top
                    
                    Text("Log In")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.bottom, 20)
                    
                    // Email Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        TextField("emma@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1)
                            )
                            .accentColor(.blue)
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        SecureField("Password...", text: $password)
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1)
                            )
                            .accentColor(.blue)
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Log In Button
                    Button {
                        Haptics.lightImpact()
                        
                        // Validate input
                        guard !email.isEmpty, !password.isEmpty else {
                            errorMessage = "Please enter both email and password"
                            return
                        }
                        
                        // Use Firebase authentication
                        isLoading = true
                        errorMessage = nil
                        
                        FirebaseUserSession.shared.signIn(email: email, password: password) { success, error in
                            isLoading = false
                            
                            if success {
                                didCompleteLogin = true
                            } else {
                                // Check if this might be a migrated user who needs password reset
                                if error?.contains("wrong-password") == true || error?.contains("user-not-found") == true {
                                    errorMessage = "Please use 'Forgot Password' to set up your new password. Your account has been migrated to our new system."
                                } else {
                                    errorMessage = error ?? "Login failed"
                                }
                            }
                        }
                    } label: {
                        Text("LOG IN")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.6 : 1.0)
                    
                    // Loading indicator
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(.top, 5)
                    }
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 5)
                    }
                    
                    // Note about authentication
                    Text("Note: Using Firebase secure authentication system")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)
                    
                    // Forgot Password Button
                    Button {
                        Haptics.lightImpact()
                        // Use Firebase password reset
                        guard !email.isEmpty else {
                            errorMessage = "Please enter your email address first"
                            return
                        }
                        
                        FirebaseUserSession.shared.resetPassword(email: email) { success, error in
                            if success {
                                errorMessage = "Password reset email sent!"
                            } else {
                                errorMessage = error ?? "Failed to send reset email"
                            }
                        }
                    } label: {
                        Text("FORGOT PASSWORD?")
                            .font(.footnote)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 10)
                    
                    Spacer() // Push Signup to bottom
                    
                    // Sign Up Button
                    Button {
                        Haptics.lightImpact()
                        needsSignUp = true
                        dismiss()
                    } label: {
                        Text("SIGNUP")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 20) // Padding at the very bottom
                    
                }
                .padding(.horizontal, 40)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    // Create dummy states for the preview
    struct PreviewWrapper: View {
        @State private var didComplete = false
        @State private var needsSignUp = false
        var body: some View {
            NavigationView { // Needed for dismiss
                LoginView(didCompleteLogin: $didComplete, needsSignUp: $needsSignUp)
            }
        }
    }
    return PreviewWrapper()
} 