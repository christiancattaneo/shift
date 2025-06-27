import SwiftUI
import PhotosUI // Needed for Photo Picker

struct SignUpView: View {
    // State variables for user input
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var agreesToTerms = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) var colorScheme // Add environment variable
    @Environment(\.dismiss) var dismiss // Keep dismiss if needed for back navigation
    
    // Binding to signal completion to the parent view
    @Binding var didCompleteSignUp: Bool

    // Helper function to upload profile image
    private func uploadProfileImage(imageData: Data) {
        guard let userId = FirebaseUserSession.shared.currentUser?.id else { return }
        
        let imagePath = "profile_images/\(userId)/profile.jpg"
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

    var body: some View {
        ZStack {
            // Use adaptive system background
            Color(.systemBackground).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Logo and Title (Smaller)
                    HStack {
                        Image("shiftlogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        Text("Shift")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            // Use primary label color
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity)

                    Text("Sign Up")
                        .font(.title)
                        .fontWeight(.bold)
                        // Use primary label color
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 20)


                    // Email Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Email")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        TextField("Enter email...", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)) // Use dark gray for background
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1) // Use gray border
                            )
                            // Use standard blue consistently
                            .accentColor(Color.blue)
                            .placeholderForegroundStyle(.primary, Color(.placeholderText))
                    }

                    // Password Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Password")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        SecureField("Enter password...", text: $password)
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)) // Use dark gray for background
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1) // Use gray border
                            )
                            // Use standard blue consistently
                            .accentColor(Color.blue)
                            .placeholderForegroundStyle(.primary, Color(.placeholderText))
                    }

                    // First Name Field
                    VStack(alignment: .leading, spacing: 5) {
                        Text("First Name")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        TextField("Enter first name...", text: $firstName)
                            .padding(12)
                            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)) // Use dark gray for background
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1) // Use gray border
                            )
                            // Use standard blue consistently
                            .accentColor(Color.blue)
                            .placeholderForegroundStyle(.primary, Color(.placeholderText))
                    }

                    // Photo Picker
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Photo (vertical best)")
                             .foregroundColor(.primary)
                             .font(.subheadline)
                        PhotosPicker(
                             selection: $selectedPhotoItem,
                             matching: .images,
                             photoLibrary: .shared()
                         ) {
                             ZStack {
                                 RoundedRectangle(cornerRadius: 10)
                                     .fill(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)) // Use dark gray background
                                     .frame(height: 200)
                                     .overlay(
                                         RoundedRectangle(cornerRadius: 10)
                                             .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1) // Use gray border
                                     )

                                 if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                     Image(uiImage: uiImage)
                                         .resizable()
                                         .scaledToFill()
                                         .frame(height: 200)
                                         .cornerRadius(10)
                                         .clipped()
                                 } else {
                                     Text("Choose Photo")
                                         // Use standard blue consistently
                                         .foregroundColor(Color.blue)
                                         .font(.headline)
                                 }
                             }
                         }
                         .onChange(of: selectedPhotoItem) { oldValue, newValue in
                             Task {
                                 if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                     selectedImageData = data
                                 }
                             }
                         }
                     }


                    // Terms Agreement
                    Toggle(isOn: $agreesToTerms) {
                         Text("User Agrees to Privacy Policy and Terms and Conditions (listed below)")
                             .font(.caption)
                             .foregroundColor(.primary)
                     }
                     // Use standard blue consistently
                     .toggleStyle(CheckboxToggleStyle(tintColor: Color.blue))
                     // Add haptic for toggle change
                     .onChange(of: agreesToTerms) { _, _ in Haptics.lightImpact() }


                    // Sign Up Button
                    Button(action: {
                        Haptics.lightImpact() // Add haptic
                        
                        // Validate input
                        guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty else {
                            errorMessage = "Please fill in all required fields"
                            return
                        }
                        
                        guard agreesToTerms else {
                            errorMessage = "Please agree to the terms and conditions"
                            return
                        }
                        
                        // Use Firebase authentication
                        isLoading = true
                        errorMessage = nil
                        
                        FirebaseUserSession.shared.signUp(email: email, password: password, firstName: firstName) { success, error in
                            isLoading = false
                            
                            if success {
                                // TODO: Upload profile image if selected
                                if let imageData = selectedImageData {
                                    uploadProfileImage(imageData: imageData)
                                }
                                didCompleteSignUp = true
                            } else {
                                errorMessage = error ?? "Sign up failed"
                            }
                        }
                    }) {
                        Text("SIGN UP")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            // Use standard blue consistently
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(!agreesToTerms || isLoading) 
                    .opacity((agreesToTerms && !isLoading) ? 1.0 : 0.6)
                    
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


                    // Links and Login Option
                    VStack(spacing: 15) {
                         HStack {
                             Button("Privacy Policy") {
                                Haptics.lightImpact() // Add haptic
                                /* TODO */ 
                             }
                                 .font(.caption)
                                 // Use standard blue consistently
                                 .foregroundColor(Color.blue)
                             Text("and")
                                 .font(.caption)
                                 .foregroundColor(.secondary) // Use secondary for 'and'
                             Button("Terms & Conditions") {
                                Haptics.lightImpact() // Add haptic
                                /* TODO */ 
                             }
                                 .font(.caption)
                                 // Use standard blue consistently
                                 .foregroundColor(Color.blue)
                         }

                         Button("ALREADY HAVE AN ACCOUNT?") {
                             Haptics.lightImpact() // Add haptic
                             // TODO: Navigate to Login Screen OR dismiss
                             dismiss() // Example: go back to previous screen
                         }
                         .font(.footnote)
                         .foregroundColor(.secondary) // Use secondary color
                         .padding(.top, 5)
                     }
                     .frame(maxWidth: .infinity)


                }
                .padding(.horizontal, 30)
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
    }
}

// Custom ToggleStyle to mimic a checkbox
struct CheckboxToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) var colorScheme // Add environment for color scheme
    var tintColor: Color = .accentColor // Default to accent

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top) {
            Button {
                configuration.isOn.toggle()
            } label: {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .resizable()
                    .frame(width: 20, height: 20)
                    // Conditional foreground color for visibility
                    .foregroundColor(
                        configuration.isOn ? 
                        tintColor : 
                        (colorScheme == .light ? Color.gray : .secondary) // Use darker gray in Light mode when off
                    )
            }
            .buttonStyle(.plain)

            configuration.label
                .padding(.leading, 5)
                .offset(y: -2)
        }
    }
}

// Extension for placeholder color modifier (iOS 17+)
// For older iOS, placeholder color might need UIKit appearance proxy or custom TextField wrapper
extension View {
    @ViewBuilder
    func placeholderForegroundStyle<S1, S2>(_ style1: S1, _ style2: S2) -> some View where S1 : ShapeStyle, S2 : ShapeStyle {
        if #available(iOS 17.0, *) {
            self.foregroundStyle(style1, style2)
        } else {
            // Fallback on earlier versions
            self.foregroundColor(Color(uiColor: .placeholderText)) // Generic placeholder color
        }
    }
}

// Preview needs modification to provide the binding
#Preview {
    // Create a dummy state for the preview
    struct PreviewWrapper: View {
        @State private var didComplete = false
        var body: some View {
            SignUpView(didCompleteSignUp: $didComplete)
        }
    }
    return NavigationView { PreviewWrapper() }
} 