import SwiftUI
import PhotosUI
import Combine

struct EditProfileView: View {
    @State private var firstName: String
    @State private var age: String
    @State private var city: String
    @State private var attractedTo: String
    @State private var approachTip: String
    @State private var instagramHandle: String
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingImagePicker = false
    
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @StateObject private var userSession = FirebaseUserSession.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let existingMember: FirebaseMember?
    private let isCreatingNew: Bool
    
    init(userMember: FirebaseMember?) {
        self.existingMember = userMember
        self.isCreatingNew = userMember == nil
        
        _firstName = State(initialValue: userMember?.firstName ?? "")
        _age = State(initialValue: userMember?.age?.description ?? "")
        _city = State(initialValue: userMember?.city ?? "")
        _attractedTo = State(initialValue: userMember?.attractedTo ?? "")
        _approachTip = State(initialValue: userMember?.approachTip ?? "")
        _instagramHandle = State(initialValue: userMember?.instagramHandle ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Profile Image Section
                    profileImageSection
                    
                    // Form Section
                    formSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(isCreatingNew ? "Complete Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isCreatingNew {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Profile Update", isPresented: $showingAlert) {
                Button("OK") {
                    if alertMessage.contains("success") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(isCreatingNew ? "Let's complete your profile" : "Update your profile")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(isCreatingNew ? "Add your details to help others discover you" : "Keep your information up to date")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Image Display
                if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                        )
                } else if let profileImage = existingMember?.profileImage, !profileImage.isEmpty {
                    AsyncImage(url: URL(string: profileImage)) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 140, height: 140)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.2)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 140, height: 140)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                                )
                        case .failure(_):
                            fallbackProfileImage
                        @unknown default:
                            fallbackProfileImage
                        }
                    }
                } else {
                    fallbackProfileImage
                }
                
                // Edit Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                                .background(
                                    Circle()
                                        .fill(Color(.systemBackground))
                                        .frame(width: 28, height: 28)
                                )
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                    Haptics.lightImpact()
                                }
                            }
                        }
                    }
                }
                .frame(width: 140, height: 140)
            }
            
            Text("Tap to update photo")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var fallbackProfileImage: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 140, height: 140)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.blue.opacity(0.7))
                    Text("Add Photo")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue.opacity(0.7))
                }
            )
    }
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Basic Info Section
            formSectionCard(title: "Basic Information") {
                VStack(spacing: 16) {
                    EnhancedTextField(
                        title: "First Name",
                        placeholder: "Enter your first name",
                        text: $firstName,
                        icon: "person",
                        isRequired: true
                    )
                    
                    EnhancedTextField(
                        title: "Age",
                        placeholder: "Enter your age",
                        text: $age,
                        icon: "calendar",
                        keyboardType: .numberPad,
                        isRequired: true
                    )
                    
                    EnhancedTextField(
                        title: "City",
                        placeholder: "Where are you located?",
                        text: $city,
                        icon: "mappin",
                        isRequired: true
                    )
                }
            }
            
            // Preferences Section
            formSectionCard(title: "Dating Preferences") {
                VStack(spacing: 16) {
                    EnhancedTextField(
                        title: "Attracted To",
                        placeholder: "e.g., Men, Women, Everyone",
                        text: $attractedTo,
                        icon: "heart"
                    )
                    
                    EnhancedTextField(
                        title: "Approach Tip",
                        placeholder: "How should someone start a conversation with you?",
                        text: $approachTip,
                        icon: "message",
                        isMultiline: true
                    )
                }
            }
            
            // Social Section
            formSectionCard(title: "Social Media") {
                EnhancedTextField(
                    title: "Instagram Handle",
                    placeholder: "@username (optional)",
                    text: $instagramHandle,
                    icon: "at",
                    prefix: "@"
                )
            }
        }
    }
    
    private func formSectionCard<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Save Button
            Button(action: saveProfile) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    }
                    
                    Text(isCreatingNew ? "Create Profile" : "Save Changes")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isFormValid && !isLoading ? [.blue, .blue.opacity(0.8)] : [.gray, .gray.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoading)
            
            // Progress Indicator
            if isCreatingNew {
                profileCompletionIndicator
            }
        }
    }
    
    private var profileCompletionIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Profile Completion")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(completionPercentage))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: completionPercentage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(y: 1.5)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !age.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var completionPercentage: Double {
        let fields = [firstName, age, city, attractedTo, approachTip, instagramHandle]
        let completedFields = fields.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let imageCompletion = selectedImageData != nil || (existingMember?.profileImage != nil) ? 1 : 0
        
        return Double(completedFields.count + imageCompletion) / 7.0 * 100
    }
    
    // MARK: - Helper Functions
    
    private func saveProfile() {
        guard isFormValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        isLoading = true
        Haptics.lightImpact()
        
        let ageInt = Int(age)
        
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else {
            alertMessage = "User not authenticated"
            showingAlert = true
            isLoading = false
            return
        }
        
        let member = FirebaseMember(
            userId: userId,
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            age: ageInt,
            city: city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : city.trimmingCharacters(in: .whitespacesAndNewlines),
            attractedTo: attractedTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : attractedTo.trimmingCharacters(in: .whitespacesAndNewlines),
            approachTip: approachTip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : approachTip.trimmingCharacters(in: .whitespacesAndNewlines),
            instagramHandle: instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines),
            profileImage: nil // TODO: Handle image upload
        )
        
        let action = isCreatingNew ? "created" : "updated"
        
        if isCreatingNew {
            membersService.createMember(member) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        Haptics.successNotification()
                        alertMessage = "Profile \(action) successfully!"
                    } else {
                        Haptics.errorNotification()
                        alertMessage = error ?? "Failed to \(action.dropLast()) profile"
                    }
                    showingAlert = true
                }
            }
        } else {
            membersService.updateMember(member) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if success {
                        Haptics.successNotification()
                        alertMessage = "Profile \(action) successfully!"
                    } else {
                        Haptics.errorNotification()
                        alertMessage = error ?? "Failed to \(action.dropLast()) profile"
                    }
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Enhanced Text Field

struct EnhancedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let keyboardType: UIKeyboardType
    let isMultiline: Bool
    let isRequired: Bool
    let prefix: String?
    
    @Environment(\.colorScheme) var colorScheme
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        keyboardType: UIKeyboardType = .default,
        isMultiline: Bool = false,
        isRequired: Bool = false,
        prefix: String? = nil
    ) {
        self.title = title
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.keyboardType = keyboardType
        self.isMultiline = isMultiline
        self.isRequired = isRequired
        self.prefix = prefix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Field Label
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if isRequired {
                    Text("*")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            
            // Input Field
            HStack {
                if let prefixText = prefix {
                    Text(prefixText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                }
                
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isFocused)
                        .padding(.vertical, 12)
                        .padding(.horizontal, prefix != nil ? 4 : 16)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isFocused)
                        .padding(.vertical, 14)
                        .padding(.horizontal, prefix != nil ? 4 : 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isFocused ? Color.blue : 
                                (isRequired && text.isEmpty ? Color.red.opacity(0.5) : Color.clear),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            // Validation Message
            if isRequired && text.isEmpty && !isFocused {
                Text("This field is required")
                    .font(.caption)
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: text.isEmpty)
    }
}

#Preview {
    NavigationView {
        EditProfileView(userMember: nil)
    }
}
