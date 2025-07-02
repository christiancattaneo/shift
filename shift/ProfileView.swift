import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userSession = FirebaseUserSession.shared
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    @State private var userData: [String: Any] = [:]
    @State private var profileImageUrl: String?
    
    var body: some View {
        NavigationStack {
            if isLoading {
                loadingSection
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Large Profile Image (like MemberDetailView)
                        profileImageSection
                        
                        // Profile Information
                        profileInformationSection
                    }
                }
                .refreshable {
                    await refreshProfile()
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSignOutAlert = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            loadUserProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userData: userData, profileImageUrl: profileImageUrl)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Haptics.lightImpact()
                userSession.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - UI Components
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var profileImageSection: some View {
        ZStack(alignment: .topLeading) {
            if let imageUrl = profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        profileImagePlaceholder(isLoading: true)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 500)
                            .clipped()
                    case .failure(let error):
                        profileImagePlaceholder(isLoading: false)
                    @unknown default:
                        profileImagePlaceholder(isLoading: false)
                    }
                }
            } else {
                profileImagePlaceholder(isLoading: false)
            }
        }
    }
    
    private func profileImagePlaceholder(isLoading: Bool) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 500)
            .overlay {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(getDisplayName().prefix(1).uppercased())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
            }
    }
    
    private var profileInformationSection: some View {
        VStack(spacing: 24) {
            // Name and Age Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(getDisplayName())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let age = userData["age"] as? Int {
                        HStack(spacing: 4) {
                            Image(systemName: "birthday.cake")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(age)")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // Information Sections
            VStack(spacing: 24) {
                // Location
                if let city = userData["city"] as? String, !city.isEmpty {
                    ProfileInfoRow(
                        icon: "location",
                        iconColor: .blue,
                        title: "Location",
                        value: city
                    )
                }
                
                // Gender
                if let gender = userData["gender"] as? String, !gender.isEmpty {
                    ProfileInfoRow(
                        icon: "person.crop.circle",
                        iconColor: .purple,
                        title: "Gender", 
                        value: gender.capitalized
                    )
                }
                
                // Approach Tip
                if let approachTip = userData["howToApproachMe"] as? String, !approachTip.isEmpty {
                    ProfileInfoRow(
                        icon: "lightbulb",
                        iconColor: .orange,
                        title: "Tip to Approach Me",
                        value: approachTip
                    )
                }
                
                // Attracted To
                if let attractedTo = userData["attractedTo"] as? String, !attractedTo.isEmpty {
                    ProfileInfoRow(
                        icon: "heart",
                        iconColor: .pink,
                        title: "Attracted to",
                        value: attractedTo.capitalized
                    )
                }
                
                // Instagram Handle
                if let handle = userData["instagramHandle"] as? String, !handle.isEmpty {
                    ProfileInfoRow(
                        icon: "camera",
                        iconColor: .purple,
                        title: "Instagram",
                        value: handle.hasPrefix("@") ? handle : "@\(handle)"
                    )
                }
            }
            
            // Edit Profile Button
            Button(action: {
                Haptics.lightImpact()
                showEditProfile = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.headline)
                    Text("Edit Profile")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.top, 20)
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    // MARK: - Helper Functions
    
    private func loadUserProfile() {
        // For migrated users, find the document by email since Firebase Auth UID != document ID
        guard let firebaseAuthUser = userSession.firebaseAuthUser else {
            print("❌ No Firebase Auth user found")
            isLoading = false
            return
        }
        
        let userEmail = firebaseAuthUser.email ?? ""
        print("🔐 Finding migrated user document by email: \(userEmail)")
        
        isLoading = true
        
        Task {
            do {
                let db = Firestore.firestore()
                
                // Search for user document by email (since migrated users have UUID document IDs)
                let querySnapshot = try await db.collection("users")
                    .whereField("email", isEqualTo: userEmail)
                    .limit(to: 1)
                    .getDocuments()
                
                await MainActor.run {
                    if let document = querySnapshot.documents.first {
                        let data = document.data()
                        print("✅ Found migrated user document: \(document.documentID)")
                        print("✅ User data loaded: \(data.keys.joined(separator: ", "))")
                        userData = data
                        
                        // Universal image URL construction for ALL users (migrated + future)
                        let documentId = document.documentID
                        let imageUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/profiles%2F\(documentId).jpg?alt=media"
                        profileImageUrl = imageUrl
                        print("🖼️ Using universal image URL for \(documentId): \(imageUrl)")
                    } else {
                        print("❌ No user document found for email: \(userEmail)")
                        userData = [:]
                        profileImageUrl = nil
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("❌ Error finding user profile: \(error)")
                    isLoading = false
                }
            }
        }
    }
    
    private func refreshProfile() async {
        loadUserProfile()
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func getDisplayName() -> String {
        if let firstName = userData["firstName"] as? String, !firstName.isEmpty {
            return firstName
        }
        return userSession.currentUser?.firstName ?? "Unknown User"
    }
}

// MARK: - Supporting Views

struct ProfileInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    ProfileView()
} 