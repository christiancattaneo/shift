import SwiftUI

struct EmailLinkAuthView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)
                        
                        // Logo Section
                        logoSection
                        
                        // Title Section
                        titleSection
                        
                        // Input Section
                        inputSection
                        
                        // Send Link Button
                        sendLinkButton
                        
                        // Status Messages
                        statusSection
                        
                        // Info Section
                        infoSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmailLinkSignInSuccess"))) { _ in
            successMessage = "Sign in successful! Welcome to Shift."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmailLinkSignInError"))) { notification in
            if let error = notification.object as? String {
                errorMessage = error
            } else {
                errorMessage = "Email link authentication failed"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EmailLinkNeedsEmail"))) { notification in
            if notification.object as? String != nil {
                // Show alert asking for email if we have the link but no stored email
                errorMessage = "Please enter your email address to complete sign in"
            }
        }
    }
    
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
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("Passwordless Sign In")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Sign in securely with just your email")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var inputSection: some View {
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
    }
    
    private var sendLinkButton: some View {
        Button(action: sendEmailLink) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Send Sign In Link")
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
    }
    
    private var statusSection: some View {
        VStack(spacing: 12) {
            // Success Message
            if let successMessage = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Error Message
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
        .animation(.easeInOut(duration: 0.3), value: successMessage)
    }
    
    private var infoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
                
                Text("How it works")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                infoRow(icon: "1.circle.fill", text: "Enter your email address")
                infoRow(icon: "2.circle.fill", text: "We'll send you a secure link")
                infoRow(icon: "3.circle.fill", text: "Tap the link to sign in instantly")
            }
            
            Text("No password required • Secure & convenient")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && email.contains("@")
    }
    
    private func sendEmailLink() {
        guard isFormValid else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        hideKeyboard()
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        FirebaseUserSession.shared.sendSignInLink(email: trimmedEmail) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    successMessage = "Sign in link sent! Check your email and tap the link to continue."
                    // Clear form
                    email = ""
                } else {
                    errorMessage = error ?? "Failed to send sign in link. Please try again."
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    EmailLinkAuthView()
} 