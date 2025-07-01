import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Binding to signal completion
    @Binding var didCompleteLogin: Bool
    
    // Binding to potentially switch back to Sign Up view
    @Binding var needsSignUp: Bool

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)
                    
                    // Logo Section
                    logoSection
                    
                    // Welcome Text
                    welcomeSection
                    
                    // Input Fields
                    inputFieldsSection
                    
                    // Login Button
                    loginButtonSection
                    
                    // Error Message
                    errorSection
                    
                    Spacer(minLength: 40)
                    
                    // Footer Actions
                    footerSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - UI Components
    
    private var logoSection: some View {
        VStack(spacing: 12) {
            Image("shiftlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            
            Text("Shift")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 8) {
            Text("Welcome Back")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Sign in to continue your journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var inputFieldsSection: some View {
        VStack(spacing: 20) {
            // Email Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Enter your email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .textContentType(.emailAddress)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(email.isEmpty ? Color.clear : Color.blue.opacity(0.5), lineWidth: 1)
                )
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    if showPassword {
                        TextField("Enter your password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                    }
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(password.isEmpty ? Color.clear : Color.blue.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    private var loginButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: handleLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Sign In")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isFormValid ? [Color.blue, Color.blue.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: isFormValid ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!isFormValid || isLoading)
            .scaleEffect(isLoading ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isLoading)
            
            // Forgot Password
            Button(action: handleForgotPassword) {
                Text("Forgot Password?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            .disabled(isLoading)
        }
    }
    
    private var errorSection: some View {
        Group {
            if let errorMessage = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: errorMessage)
    }
    
    private var footerSection: some View {
        VStack(spacing: 16) {
            // Divider with text
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
                
                Text("New to Shift?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            // Sign Up Button
            Button(action: {
                Haptics.lightImpact()
                needsSignUp = true
                dismiss()
            }) {
                Text("Create Account")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            .disabled(isLoading)
            
            // App info
            Text("Secure authentication powered by Firebase")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        email.contains("@")
    }
    
    // MARK: - Actions
    
    private func handleLogin() {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password"
            return
        }
        
        Haptics.lightImpact()
        hideKeyboard()
        
        isLoading = true
        errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        FirebaseUserSession.shared.signIn(email: trimmedEmail, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    Haptics.successNotification()
                    didCompleteLogin = true
                } else {
                    Haptics.errorNotification()
                    
                    if error?.contains("wrong-password") == true || error?.contains("user-not-found") == true {
                        errorMessage = "Account migrated to new system. Please use 'Forgot Password' to set up your new password."
                    } else if error?.contains("invalid-email") == true {
                        errorMessage = "Please enter a valid email address."
                    } else if error?.contains("too-many-requests") == true {
                        errorMessage = "Too many failed attempts. Please try again later."
                    } else {
                        errorMessage = error ?? "Sign in failed. Please try again."
                    }
                }
            }
        }
    }
    
    private func handleForgotPassword() {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email address first"
            return
        }
        
        Haptics.lightImpact()
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        FirebaseUserSession.shared.resetPassword(email: trimmedEmail) { success, error in
            DispatchQueue.main.async {
                if success {
                    Haptics.successNotification()
                    errorMessage = "Password reset email sent! Check your inbox."
                } else {
                    Haptics.errorNotification()
                    errorMessage = error ?? "Failed to send reset email. Please try again."
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var didComplete = false
        @State private var needsSignUp = false
        
        var body: some View {
            NavigationView {
                LoginView(didCompleteLogin: $didComplete, needsSignUp: $needsSignUp)
            }
        }
    }
    
    return PreviewWrapper()
} 