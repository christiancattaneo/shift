import SwiftUI

// Placeholder data model for User Profile
// Expand this later with actual data
struct UserProfile: Identifiable {
    let id = UUID()
    var firstName: String
    var age: Int
    var city: String
    var approachTip: String
    var attractedTo: String
    var instagramHandle: String?
    var profileImageName: String? // For placeholder or actual image
}

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss // Although likely not used if it's a main tab
    @Environment(\.colorScheme) var colorScheme
    
    // Example Profile Data - Replace with actual logged-in user data later
    @State private var userProfile = UserProfile(
        firstName: "Maria",
        age: 28,
        city: "Austin, TX",
        approachTip: "Ask about my latest travel adventure!",
        attractedTo: "Male",
        instagramHandle: "maria_travels",
        profileImageName: nil // Use nil to show placeholder initially
    )

    var body: some View {
        NavigationView { // Add NavigationView for the nav bar styling
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Large Image Placeholder Area
                    ZStack {
                        Rectangle()
                            .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                            .aspectRatio(1.0, contentMode: .fit) // Square aspect ratio
                            
                        Image(systemName: "photo.on.rectangle.angled")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100)
                            .foregroundColor(.secondary)
                        
                        // TODO: Add actual image loading here if userProfile.profileImageName != nil
                    }
                    .padding(.bottom, 15)

                    // User Info Section
                    VStack(alignment: .leading, spacing: 15) {
                        // Name & Age
                        HStack(alignment: .firstTextBaseline) {
                            Text(userProfile.firstName)
                                .font(.largeTitle.weight(.bold))
                            Spacer()
                             HStack(spacing: 5) {
                                Image(systemName: "birthday.cake") // Example icon for age
                                Text("\(userProfile.age)")
                             }
                             .font(.title3)
                             .foregroundColor(.secondary)
                        }
                        
                        Divider()

                        // City
                        InfoRow(icon: "mappin.and.ellipse", label: "City", value: userProfile.city)
                        
                        // Tip to Approach
                        InfoRow(icon: "lightbulb.fill", label: "Tip to Approach Me", value: userProfile.approachTip)
                        
                        // Attracted To
                        InfoRow(icon: "figure.dress.line.vertical.figure", label: "Attracted to", value: userProfile.attractedTo) // Adjust icon based on gender/preference?
                        
                        // Instagram (Optional)
                        if let handle = userProfile.instagramHandle, !handle.isEmpty {
                             InfoRow(icon: "at", label: "Instagram", value: handle)
                        }
                        
                        Divider()
                        
                        // Add more sections as needed (e.g., Bio, Photos, Interests)
                        
                        Spacer() // Pushes content up if ScrollView is short
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Use toolbar for navigation bar items
                // Leading Item (Back Button - might not be needed in TabView)
                // ToolbarItem(placement: .navigationBarLeading) {
                //     Button { dismiss() } label: {
                //         Image(systemName: "chevron.left")
                //     }
                // }
                
                // Principal Item (Title)
                ToolbarItem(placement: .principal) {
                    Text(userProfile.firstName)
                        .font(.headline)
                }
                
                // Trailing Item (Edit Button)
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Wrap the Button's label in NavigationLink
                    NavigationLink(destination: EditProfileView(profileToEdit: userProfile)) {
                        Image(systemName: "pencil.circle") // Edit icon
                            .font(.title2)
                            // Ensure link doesn't override color
                            .foregroundColor(.accentColor) 
                    }
                    
                    // Original Button (if you want separate action vs navigation)
                    // Button {
                    //     // TODO: Navigate to Edit Profile Screen
                    //     print("Edit Profile Tapped")
                    // } label: {
                    //     Image(systemName: "pencil.circle") // Edit icon
                    //         .font(.title2)
                    // }
                }
            }
            // Optional: Set toolbar background color
            // .toolbarBackground(colorScheme == .dark ? .black : .white, for: .navigationBar)
            // .toolbarBackground(.visible, for: .navigationBar)
        }
        .accentColor(.blue) // Set accent color for toolbar items
    }
}

// Reusable row for profile details
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20) // Align icons
                Text(label)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.body)
                .padding(.leading, 28) // Indent value below icon
        }
    }
}

#Preview {
    ProfileView()
} 