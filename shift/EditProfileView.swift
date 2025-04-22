import SwiftUI
import PhotosUI // For photo picker

struct EditProfileView: View {
    // Use the existing UserProfile struct or adapt if needed
    // We'll use @State to allow editing of a *copy* of the profile data
    @State private var editableProfile: UserProfile 
    
    // State for photo picker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil // To hold new image data
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Colors
    let subscribeButtonColor = Color.pink
    let signOutButtonColor = Color.secondary.opacity(0.4)
    
    // Initializer to accept the profile data to edit
    // In a real app, this would come from your data source (logged-in user)
    init(profileToEdit: UserProfile) {
        _editableProfile = State(initialValue: profileToEdit)
        // TODO: If profileToEdit has existing image data, load it into selectedImageData
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // --- Profile Image Section ---
                ZStack(alignment: .bottomTrailing) {
                    // Image Placeholder/Display
                    ZStack {
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                            .aspectRatio(1.0, contentMode: .fit) // Square aspect ratio
                        
                        if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .aspectRatio(1.0, contentMode: .fill) 
                                .clipped()
                        } else {
                            // Placeholder icon if no image
                            Image(systemName: "photo.on.rectangle.angled")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Photo Picker Button (overlayed)
                    PhotosPicker(
                         selection: $selectedPhotoItem,
                         matching: .images,
                         photoLibrary: .shared()
                     ) {
                         Image(systemName: "pencil.circle.fill")
                             .font(.system(size: 30))
                             .foregroundColor(.blue)
                             .background(Color(.systemBackground).clipShape(Circle())) // Background for contrast
                             .padding(5)
                     }
                     .onChange(of: selectedPhotoItem) { _, newItem in
                         Task {
                             if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                 selectedImageData = data
                             }
                         }
                     }
                }
                .padding(.bottom, 10)

                // --- Name, Email, Subscribe ---
                VStack {
                    Text(editableProfile.firstName) // Display name, maybe not editable here?
                        .font(.title.weight(.bold))
                    Text("email@example.com") // Placeholder for email
                        .font(.subheadline)
                        .foregroundColor(.blue) // Style as a link?
                    
                    HStack(spacing: 15) {
                         Button { /* TODO: Subscribe Action */ } label: {
                             Text("+ SUBSCRIBE")
                                 .font(.caption.weight(.bold))
                                 .foregroundColor(.white)
                                 .padding(.horizontal, 15)
                                 .padding(.vertical, 8)
                                 .background(subscribeButtonColor)
                                 .clipShape(Capsule())
                         }
                        Button { /* TODO: Unsubscribe Action */ } label: {
                             Text("UNSUBSCRIBE")
                                 .font(.caption)
                                 .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 5)
                }
                
                Divider().padding(.vertical, 10)

                // --- Your Profile Section ---
                VStack(alignment: .leading, spacing: 15) {
                    Text("Your Profile")
                        .font(.title2.weight(.bold))
                        .padding(.bottom, 5)
                    
                    // Reusable TextField Row Component
                    ProfileTextField(label: "Username", placeholder: "Enter username...", text: .constant("")) // Use binding later
                    ProfileTextField(label: "First Name", placeholder: "Enter first name...", text: $editableProfile.firstName)
                    ProfileTextField(label: "City", placeholder: "Search by name or address...", icon: "mappin", text: $editableProfile.city)
                    ProfileTextField(label: "Age", placeholder: "Enter age...", keyboardType: .numberPad, text: Binding( // Binding for Int
                        get: { "\(editableProfile.age)" },
                        set: { editableProfile.age = Int($0) ?? editableProfile.age }
                    ))
                    
                    // Photo Section (Different style here)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Photo")
                            .foregroundColor(.primary)
                            .font(.subheadline)
                        // This reuses the picker logic/display from above essentially
                        // In a real app, you'd likely have a more complex photo management grid here
                         PhotosPicker(
                             selection: $selectedPhotoItem,
                             matching: .images, 
                             photoLibrary: .shared()
                         ) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6)) 
                                    .frame(height: 150)
                                
                                if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .cornerRadius(10)
                                        .clipped()
                                } else {
                                    Text("Choose Photo")
                                        .foregroundColor(.blue)
                                        .font(.headline)
                                }
                            }
                         }
                    }
                    
                    ProfileTextField(label: "Gender", placeholder: "Enter gender... (Male, Female, Nonbinary)", text: .constant("")) // Add binding
                    ProfileTextField(label: "Attracted to", placeholder: "Enter attracted to... (Female, Male, Nonbinary)", text: $editableProfile.attractedTo)
                    ProfileTextField(label: "Tip to Approach Me", placeholder: "Enter tip to approach me...", text: $editableProfile.approachTip)
                    ProfileTextField(label: "Instagram Handle", placeholder: "Enter instagram handle...", text: Binding( // Optional Binding
                        get: { editableProfile.instagramHandle ?? "" },
                        set: { editableProfile.instagramHandle = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Spacer(minLength: 30)

                // --- Action Buttons ---
                VStack(spacing: 15) {
                    Button {
                        // TODO: Implement Update Profile Logic (save editableProfile)
                        print("Update Profile Tapped")
                        dismiss() // Dismiss after update
                    } label: {
                        Text("UPDATE PROFILE")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        // TODO: Implement Sign Out Logic
                        print("Sign Out Tapped")
                        // Need to dismiss all the way back to auth screen? Requires different state management.
                    } label: {
                         Text("SIGN OUT")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(signOutButtonColor)
                            .cornerRadius(10)
                    }
                    
                     Button {
                        // TODO: Implement Delete Account Logic (with confirmation)
                        print("Delete Account Tapped")
                    } label: {
                        Text("DELETE ACCOUNT")
                            .font(.footnote)
                            .foregroundColor(.red) // Destructive action color
                    }
                    .padding(.top, 10)
                    
                    Divider().padding(.vertical, 10)
                    
                    Text("For Support or Feedback: Info@shift.dating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            }
            .padding(.horizontal)
            .padding(.bottom) // Padding at the very bottom
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false) // Use default back button
        .toolbar {
             // Keep the default back button, remove custom leading item
             // Add trailing save button if needed instead of UPDATE PROFILE button below
             // ToolbarItem(placement: .navigationBarTrailing) {
             //     Button("Save") { /* Save logic */ dismiss() } 
             // }
        }
    }
}

// Reusable TextField Row Component for Edit Profile
struct ProfileTextField: View {
    let label: String
    let placeholder: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    @Binding var text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .foregroundColor(.primary)
                .font(.subheadline)
            HStack {
                if let iconName = icon {
                    Image(systemName: iconName)
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .padding(.vertical, 12)
                    .padding(.leading, icon == nil ? 12 : 5)
                    .padding(.trailing, 12)
            }
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(colorScheme == .dark ? Color(.systemGray) : Color(.systemGray3), lineWidth: 1)
            )
        }
    }
}


// Preview needs setup
#Preview {
    // Create sample data for preview
    let sampleProfile = UserProfile(
        firstName: "Maria",
        age: 28,
        city: "Austin, TX",
        approachTip: "Ask about my latest travel adventure!",
        attractedTo: "Male",
        instagramHandle: "maria_travels",
        profileImageName: nil
    )
    // Wrap in NavigationView for toolbar display
    NavigationView {
        EditProfileView(profileToEdit: sampleProfile)
    }
} 