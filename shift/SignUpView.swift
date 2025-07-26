import SwiftUI
import PhotosUI

struct SignUpView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var agreesToTerms = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    
    @Binding var didCompleteSignUp: Bool

    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    // Logo Section
                    logoSection
                    
                    // Welcome Section
                    welcomeSection
                    
                    // Profile Photo Section
                    photoPickerSection
                    
                    // Input Fields
                    inputFieldsSection
                    
                    // Terms Agreement
                    termsSection
                    
                    // Sign Up Button
                    signUpButtonSection
                    
                    // Error Section
                    errorSection
                    
                    Spacer(minLength: 40)
                    
                    // Footer
                    footerSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
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
            Text("Join Shift")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Create your profile and start connecting")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var photoPickerSection: some View {
        VStack(spacing: 12) {
            Text("Profile Photo")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedImageData != nil ? Color.blue.opacity(0.5) : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    
                    if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Add Profile Photo")
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            Text("Tap to choose from your photos")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            selectedImageData = data
                            Haptics.lightImpact()
                        }
                    }
                }
            }
            
            if selectedImageData != nil {
                Text("Great photo! You can change it later in your profile.")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedImageData)
    }
    
    private var inputFieldsSection: some View {
        VStack(spacing: 20) {
            // First Name Field
            VStack(alignment: .leading, spacing: 8) {
                Text("First Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    TextField("Enter your first name", text: $firstName)
                        .autocorrectionDisabled()
                        .textContentType(.givenName)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(firstName.isEmpty ? Color.clear : Color.blue.opacity(0.5), lineWidth: 1)
                )
            }
            
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
                        .stroke(email.isEmpty ? Color.clear : (isValidEmail ? Color.blue.opacity(0.5) : Color.red.opacity(0.5)), lineWidth: 1)
                )
                
                if !email.isEmpty && !isValidEmail {
                    Text("Please enter a valid email address")
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
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
                        TextField("Create a password", text: $password)
                            .textContentType(.newPassword)
                    } else {
                        SecureField("Create a password", text: $password)
                            .textContentType(.newPassword)
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
                        .stroke(password.isEmpty ? Color.clear : (isValidPassword ? Color.blue.opacity(0.5) : Color.red.opacity(0.5)), lineWidth: 1)
                )
                
                if !password.isEmpty && !isValidPassword {
                    Text("Password must be at least 6 characters")
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: email)
        .animation(.easeInOut(duration: 0.2), value: password)
    }
    
    private var termsSection: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: {
                    agreesToTerms.toggle()
                    Haptics.lightImpact()
                }) {
                    Image(systemName: agreesToTerms ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(agreesToTerms ? .blue : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("I agree to the Terms of Service and Privacy Policy")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Button("Privacy Policy") {
                            Haptics.lightImpact()
                            showPrivacyPolicy = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Terms of Service") {
                            Haptics.lightImpact()
                            showTermsOfService = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private var signUpButtonSection: some View {
        Button(action: handleSignUp) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Create Account")
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
                
                Text("Already have an account?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.secondary.opacity(0.3))
            }
            
            // Sign In Button
            Button(action: {
                Haptics.lightImpact()
                dismiss()
            }) {
                Text("Sign In")
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
    
    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }
    
    private var isValidPassword: Bool {
        password.count >= 6
    }
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isValidEmail &&
        isValidPassword &&
        agreesToTerms
    }
    
    // MARK: - Actions
    
    private func handleSignUp() {
        guard isFormValid else {
            errorMessage = "Please complete all required fields correctly"
            return
        }
        
        Haptics.lightImpact()
        hideKeyboard()
        
        isLoading = true
        errorMessage = nil
        
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        FirebaseUserSession.shared.signUp(email: trimmedEmail, password: password, firstName: trimmedFirstName) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Upload profile image if selected
                    if let imageData = selectedImageData {
                        uploadProfileImage(imageData: imageData)
                    }
                    
                    Haptics.successNotification()
                    didCompleteSignUp = true
                } else {
                    Haptics.errorNotification()
                    isLoading = false
                    
                    if error?.contains("email-already-in-use") == true {
                        errorMessage = "This email is already registered. Try signing in instead."
                    } else if error?.contains("weak-password") == true {
                        errorMessage = "Password is too weak. Please choose a stronger password."
                    } else if error?.contains("invalid-email") == true {
                        errorMessage = "Please enter a valid email address."
                    } else {
                        errorMessage = error ?? "Account creation failed. Please try again."
                    }
                }
            }
        }
    }
    
    private func uploadProfileImage(imageData: Data) {
        guard let userId = FirebaseUserSession.shared.currentUser?.id else { return }
        
                        let imagePath = "profiles/\(userId).jpg"
        FirebaseStorageService().uploadImage(imageData, path: imagePath) { imageUrl, error in
            if let imageUrl = imageUrl {
                // Update user profile with image URL
                if let currentUser = FirebaseUserSession.shared.currentUser {
                    let updatedUser = FirebaseUser(
                        email: currentUser.email,
                        firstName: currentUser.firstName,
                        fullName: currentUser.fullName,
                        profilePhoto: imageUrl,
                        username: currentUser.username,
                        gender: currentUser.gender,
                        attractedTo: currentUser.attractedTo,
                        age: currentUser.age,
                        city: currentUser.city,
                        howToApproachMe: currentUser.howToApproachMe,
                        isEventCreator: currentUser.isEventCreator,
                        instagramHandle: currentUser.instagramHandle
                    )
                    
                    FirebaseUserSession.shared.updateUserProfile(updatedUser) { success, error in
                        if !success {
                            print("Failed to update user profile with image: \(error ?? "Unknown error")")
                        }
                    }
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
        
        var body: some View {
            NavigationView {
                SignUpView(didCompleteSignUp: $didComplete)
            }
        }
    }
    
    return PreviewWrapper()
} 