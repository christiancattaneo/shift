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
    
    @StateObject private var membersService = FirebaseMembersService()
    @StateObject private var userSession = FirebaseUserSession.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let existingMember: FirebaseMember?
    private let isCreatingNew: Bool
    
    // Initializer for editing existing member
    init(userMember: FirebaseMember?) {
        self.existingMember = userMember
        self.isCreatingNew = userMember == nil
        
        // Initialize state with existing data or empty values
        _firstName = State(initialValue: userMember?.firstName ?? "")
        _age = State(initialValue: userMember?.age?.description ?? "")
        _city = State(initialValue: userMember?.city ?? "")
        _attractedTo = State(initialValue: userMember?.attractedTo ?? "")
        _approachTip = State(initialValue: userMember?.approachTip ?? "")
        _instagramHandle = State(initialValue: userMember?.instagramHandle ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Image Section
                VStack(spacing: 15) {
                    ZStack(alignment: .bottomTrailing) {
                        // Image Display
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else if let profileImage = existingMember?.profileImage, !profileImage.isEmpty {
                            AsyncImage(url: URL(string: profileImage)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
                        }
                        
                        // Photo Picker Button
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                                .background(Color(.systemBackground).clipShape(Circle()))
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedImageData = data
                                }
                            }
                        }
                    }
                    
                    Text(isCreatingNew ? "Complete Your Profile" : "Edit Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)

                // Profile Form
                VStack(spacing: 15) {
                    ProfileTextField(
                        label: "First Name",
                        placeholder: "Enter your first name",
                        text: $firstName
                    )
                    
                    ProfileTextField(
                        label: "Age",
                        placeholder: "Enter your age",
                        keyboardType: .numberPad,
                        text: $age
                    )
                    
                    ProfileTextField(
                        label: "City",
                        placeholder: "Enter your city",
                        icon: "mappin",
                        text: $city
                    )
                    
                    ProfileTextField(
                        label: "Attracted To",
                        placeholder: "e.g., Male, Female, Non-binary",
                        text: $attractedTo
                    )
                    
                    ProfileTextField(
                        label: "Approach Tip",
                        placeholder: "How should someone approach you?",
                        isMultiline: true,
                        text: $approachTip
                    )
                    
                    ProfileTextField(
                        label: "Instagram Handle",
                        placeholder: "@username (optional)",
                        text: $instagramHandle
                    )
                }
                .padding(.horizontal)
                
                Spacer(minLength: 30)

                // Action Buttons
                VStack(spacing: 15) {
                    Button(action: saveProfile) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isCreatingNew ? "Create Profile" : "Update Profile")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isLoading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || firstName.isEmpty)
                    
                    if !isCreatingNew {
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle(isCreatingNew ? "Complete Profile" : "Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func saveProfile() {
        guard !firstName.isEmpty else {
            alertMessage = "First name is required"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        let ageInt = Int(age)
        
        // Use Firebase user session to get current user ID
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else {
            alertMessage = "User not authenticated"
            showingAlert = true
            return
        }
        
        let member = FirebaseMember(
            userId: userId,
            firstName: firstName,
            age: ageInt,
            city: city.isEmpty ? nil : city,
            attractedTo: attractedTo.isEmpty ? nil : attractedTo,
            approachTip: approachTip.isEmpty ? nil : approachTip,
            instagramHandle: instagramHandle.isEmpty ? nil : instagramHandle,
            profileImage: nil // TODO: Handle image upload
        )
        
        if isCreatingNew {
            membersService.createMember(member) { success, error in
                isLoading = false
                if success {
                    alertMessage = "Profile created successfully!"
                } else {
                    alertMessage = error ?? "Failed to create profile"
                }
                showingAlert = true
            }
        } else {
            membersService.updateMember(member) { success, error in
                isLoading = false
                if success {
                    alertMessage = "Profile updated successfully!"
                } else {
                    alertMessage = error ?? "Failed to update profile"
                }
                showingAlert = true
            }
        }
        
        // The actual Firebase call happens above with completion handlers
    }
}

// Updated ProfileTextField to support multiline
struct ProfileTextField: View {
    let label: String
    let placeholder: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isMultiline: Bool = false
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .foregroundColor(.primary)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                
                if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .keyboardType(keyboardType)
                        .lineLimit(3...6)
                        .padding(.vertical, 12)
                        .padding(.leading, icon == nil ? 12 : 5)
                        .padding(.trailing, 12)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .padding(.vertical, 12)
                        .padding(.leading, icon == nil ? 12 : 5)
                        .padding(.trailing, 12)
                }
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    NavigationView {
        EditProfileView(userMember: nil)
    }
} 