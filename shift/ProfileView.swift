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
                        // Enhanced Profile Image Section
                        profileImageSection
                        
                        // Enhanced Profile Information
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
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
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
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.blue)
            
            VStack(spacing: 8) {
                Text("Loading your profile...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Just a moment")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.blue.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var profileImageSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.15),
                    Color.pink.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 400)
            
            // Profile image or placeholder
            if let imageUrl = profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        profileImagePlaceholder(isLoading: true)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 400)
                            .clipped()
                            .overlay(
                                // Subtle overlay for better text readability
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    case .failure(_):
                        profileImagePlaceholder(isLoading: false)
                    @unknown default:
                        profileImagePlaceholder(isLoading: false)
                    }
                }
            } else {
                profileImagePlaceholder(isLoading: false)
            }
            
            // Name overlay at bottom
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDisplayName())
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        
                        if let age = userData["age"] as? Int {
                            HStack(spacing: 6) {
                                Image(systemName: "birthday.cake.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(age) years old")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .cornerRadius(0)
    }
    
    private func profileImagePlaceholder(isLoading: Bool) -> some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.2),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.2),
                    Color.orange.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 400)
            
            // Content
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading image...")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // Large initial letter
                    Text(getDisplayName().prefix(1).uppercased())
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 4) {
                        Text("Profile Photo")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Tap edit to add one")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
            }
        }
    }
    
    private var profileInformationSection: some View {
        VStack(spacing: 0) {
            // White background section
            VStack(spacing: 32) {
                // Information Cards
                LazyVStack(spacing: 20) {
                    // Location Card
                    if let city = userData["city"] as? String, !city.isEmpty {
                        EnhancedInfoCard(
                            icon: "location.fill",
                            iconColor: .blue,
                            iconBackground: .blue.opacity(0.1),
                            title: "Location",
                            value: city
                        )
                    }
                    
                    // Gender Card
                    if let gender = userData["gender"] as? String, !gender.isEmpty {
                        EnhancedInfoCard(
                            icon: "person.crop.circle.fill",
                            iconColor: .purple,
                            iconBackground: .purple.opacity(0.1),
                            title: "Gender", 
                            value: gender.capitalized
                        )
                    }
                    
                    // Approach Tip Card
                    if let approachTip = userData["howToApproachMe"] as? String, !approachTip.isEmpty {
                        EnhancedInfoCard(
                            icon: "lightbulb.fill",
                            iconColor: .orange,
                            iconBackground: .orange.opacity(0.1),
                            title: "How to Approach Me",
                            value: approachTip,
                            isLargeText: true
                        )
                    }
                    
                    // Attracted To Card
                    if let attractedTo = userData["attractedTo"] as? String, !attractedTo.isEmpty {
                        EnhancedInfoCard(
                            icon: "heart.fill",
                            iconColor: .pink,
                            iconBackground: .pink.opacity(0.1),
                            title: "Attracted to",
                            value: attractedTo.capitalized
                        )
                    }
                    
                    // Instagram Card
                    if let handle = userData["instagramHandle"] as? String, !handle.isEmpty {
                        EnhancedInfoCard(
                            icon: "camera.fill",
                            iconColor: .purple,
                            iconBackground: .purple.opacity(0.1),
                            title: "Instagram",
                            value: handle.hasPrefix("@") ? handle : "@\(handle)"
                        )
                    }
                }
                
                // Enhanced Edit Profile Button
                Button(action: {
                    Haptics.lightImpact()
                    showEditProfile = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Edit Profile")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .blue.opacity(0.4), radius: 12, x: 0, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .scaleEffect(showEditProfile ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showEditProfile)
                
                Spacer(minLength: 60)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.blue.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
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

// MARK: - Enhanced Supporting Views

struct EnhancedInfoCard: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let value: String
    let isLargeText: Bool
    
    init(icon: String, iconColor: Color, iconBackground: Color, title: String, value: String, isLargeText: Bool = false) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.title = title
        self.value = value
        self.isLargeText = isLargeText
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Enhanced icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.system(
                        size: isLargeText ? 16 : 18,
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundColor(.primary)
                    .lineLimit(isLargeText ? 3 : 1)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [iconColor.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    ProfileView()
} 