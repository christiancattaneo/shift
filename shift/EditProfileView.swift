import SwiftUI
import PhotosUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

struct EditProfileView: View {
    @State private var firstName: String
    @State private var age: String
    @State private var city: String
    @State private var gender: String
    @State private var attractedTo: String
    @State private var approachTip: String
    @State private var instagramHandle: String
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var uploadProgress: Double = 0.0
    @State private var isUploadingImage = false
    
    @StateObject private var userSession = FirebaseUserSession.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let userData: [String: Any]
    private let existingImageUrl: String?
    private let isCreatingNew: Bool
    
    init(userData: [String: Any] = [:], profileImageUrl: String? = nil) {
        self.userData = userData
        self.existingImageUrl = profileImageUrl
        self.isCreatingNew = userData.isEmpty || userData.count <= 2 // Just basic auth fields
        
        _firstName = State(initialValue: userData["firstName"] as? String ?? "")
        _age = State(initialValue: (userData["age"] as? Int)?.description ?? "")
        _city = State(initialValue: userData["city"] as? String ?? "")
        _gender = State(initialValue: userData["gender"] as? String ?? "")
        _attractedTo = State(initialValue: userData["attractedTo"] as? String ?? "")
        _approachTip = State(initialValue: userData["howToApproachMe"] as? String ?? "")
        _instagramHandle = State(initialValue: userData["instagramHandle"] as? String ?? "")
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
                } else if let imageUrl = existingImageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
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
            
            if isUploadingImage {
                VStack(spacing: 8) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    Text("Uploading image... \(Int(uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
            Text("Tap to update photo")
                .font(.caption)
                .foregroundColor(.secondary)
            }
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
                    
                    // Gender Picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "person.2")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("Gender")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Text("*")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        
                        Menu {
                            Button("Male") { gender = "Male"; Haptics.lightImpact() }
                            Button("Female") { gender = "Female"; Haptics.lightImpact() }
                            Button("Non-binary") { gender = "Non-binary"; Haptics.lightImpact() }
                            Button("Other") { gender = "Other"; Haptics.lightImpact() }
                        } label: {
                            HStack {
                                Text(gender.isEmpty ? "Select Gender" : gender)
                                    .foregroundColor(gender.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Preferences Section
            formSectionCard(title: "Dating Preferences") {
                VStack(spacing: 16) {
                    // Attracted To Picker
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "heart")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                            Text("Attracted To")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        Menu {
                            Button("Men") { attractedTo = "Men"; Haptics.lightImpact() }
                            Button("Women") { attractedTo = "Women"; Haptics.lightImpact() }
                            Button("Everyone") { attractedTo = "Everyone"; Haptics.lightImpact() }
                        } label: {
                            HStack {
                                Text(attractedTo.isEmpty ? "Select Preference" : attractedTo)
                                    .foregroundColor(attractedTo.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
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
                    placeholder: "username (optional)",
                    text: $instagramHandle,
                    icon: "camera",
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
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !gender.isEmpty
    }
    
    private var completionPercentage: Double {
        var completed = 0.0
        let total = 7.0
        
        if !firstName.isEmpty { completed += 1 }
        if !age.isEmpty { completed += 1 }
        if !city.isEmpty { completed += 1 }
        if !gender.isEmpty { completed += 1 }
        if !attractedTo.isEmpty { completed += 1 }
        if !approachTip.isEmpty { completed += 1 }
        if !instagramHandle.isEmpty { completed += 1 }
        if selectedImageData != nil || existingImageUrl != nil { completed += 1 }
        
        return (completed / (total + 1)) * 100
    }
    
    // MARK: - Helper Functions
    
    private func saveProfile() {
        guard isFormValid else {
            alertMessage = "Please fill in all required fields"
            showingAlert = true
            return
        }
        
        guard let firebaseAuthUser = userSession.firebaseAuthUser else {
            alertMessage = "User not authenticated"
            showingAlert = true
            return
        }
        
        let userId = firebaseAuthUser.uid
        
        isLoading = true
        Haptics.lightImpact()
        
        Task {
            do {
                var updatedData: [String: Any] = [
                    "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                    "age": Int(age) ?? 0,
                    "city": city.trimmingCharacters(in: .whitespacesAndNewlines),
                    "gender": gender,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                
                // Add optional fields only if they have values
                if !attractedTo.isEmpty {
                    updatedData["attractedTo"] = attractedTo
                }
                
                let trimmedApproachTip = approachTip.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedApproachTip.isEmpty {
                    updatedData["howToApproachMe"] = trimmedApproachTip
                }
                
                let trimmedInstagram = instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedInstagram.isEmpty {
                    updatedData["instagramHandle"] = trimmedInstagram
                }
                
                // Handle image upload if new image is selected
                if let imageData = selectedImageData {
                    let imageUrl = try await uploadProfileImage(imageData, userId: userId)
                    updatedData["profileImageUrl"] = imageUrl
                    updatedData["firebaseImageUrl"] = imageUrl
                }
                
                // Save to Firestore
                let db = Firestore.firestore()
                try await db.collection("users").document(userId).updateData(updatedData)
                
                await MainActor.run {
                    isLoading = false
                        Haptics.successNotification()
                    alertMessage = "Profile updated successfully!"
                    showingAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isLoading = false
                        Haptics.errorNotification()
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func uploadProfileImage(_ imageData: Data, userId: String) async throws -> String {
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }
        
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let imageRef = storageRef.child("profiles/\(userId).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        return try await withCheckedThrowingContinuation { continuation in
            let uploadTask = imageRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                imageRef.downloadURL { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url.absoluteString)
                    } else {
                        continuation.resume(throwing: NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                    }
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                let progress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
                DispatchQueue.main.async {
                    self.uploadProgress = progress
                }
            }
            
            uploadTask.observe(.success) { _ in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
                }
            }
            
            uploadTask.observe(.failure) { _ in
                DispatchQueue.main.async {
                    self.isUploadingImage = false
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
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .focused($isFocused)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
                    .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
        }
    }
}

#Preview {
    EditProfileView()
}

