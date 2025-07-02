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
    
    // MARK: - Screen Size Detection
    private var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    // Dynamic sizing based on screen dimensions
    private var profileImageHeight: CGFloat {
        // Responsive height: 35-45% of screen height, with min/max bounds
        let percentage: CGFloat = 0.4
        let calculatedHeight = screenHeight * percentage
        return max(300, min(calculatedHeight, 500)) // Min 300, Max 500
    }
    
    private var nameFontSize: CGFloat {
        // Responsive font size based on screen width
        let baseFontSize: CGFloat = screenWidth * 0.08
        return max(24, min(baseFontSize, 36)) // Min 24, Max 36
    }
    
    private var ageFontSize: CGFloat {
        let baseFontSize: CGFloat = screenWidth * 0.045
        return max(14, min(baseFontSize, 20)) // Min 14, Max 20
    }
    
    private var dynamicHorizontalPadding: CGFloat {
        // Responsive padding based on screen width
        let percentage: CGFloat = 0.06
        let calculatedPadding = screenWidth * percentage
        return max(16, min(calculatedPadding, 32)) // Min 16, Max 32
    }
    
    private var dynamicVerticalSpacing: CGFloat {
        // Responsive spacing based on screen height
        let percentage: CGFloat = 0.025
        let calculatedSpacing = screenHeight * percentage
        return max(16, min(calculatedSpacing, 32)) // Min 16, Max 32
    }

    var body: some View {
        NavigationStack {
            if isLoading {
                loadingSection
            } else {
                GeometryReader { geometry in
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
        VStack(spacing: dynamicVerticalSpacing) {
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
            .frame(height: profileImageHeight)
            
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
                            .frame(height: profileImageHeight)
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
            
            // Name overlay at bottom - Responsive positioning
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getDisplayName())
                            .font(.system(size: nameFontSize, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7) // Allow text to scale down if needed
                        
                        if let age = userData["age"] as? Int {
                            HStack(spacing: 6) {
                                Image(systemName: "birthday.cake.fill")
                                    .font(.system(size: ageFontSize * 0.8))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("\(age) years old")
                                    .font(.system(size: ageFontSize, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, dynamicHorizontalPadding)
                .padding(.bottom, max(20, dynamicVerticalSpacing * 0.75))
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
            .frame(height: profileImageHeight)
            
            // Content - Responsive sizing
            VStack(spacing: max(12, dynamicVerticalSpacing * 0.5)) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading image...")
                        .font(.system(size: max(14, ageFontSize * 0.8), weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // Large initial letter - Responsive size
                    Text(getDisplayName().prefix(1).uppercased())
                        .font(.system(size: nameFontSize * 2.2, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 4) {
                        Text("Profile Photo")
                            .font(.system(size: ageFontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        Text("Tap edit to add one")
                            .font(.system(size: ageFontSize * 0.8, weight: .medium, design: .rounded))
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
            VStack(spacing: dynamicVerticalSpacing) {
                // Information Cards
                LazyVStack(spacing: max(16, dynamicVerticalSpacing * 0.6)) {
                    // Location Card
                    if let city = userData["city"] as? String, !city.isEmpty {
                        EnhancedInfoCard(
                            icon: "location.fill",
                            iconColor: .blue,
                            iconBackground: .blue.opacity(0.1),
                            title: "Location",
                            value: city,
                            screenWidth: screenWidth
                        )
                    }
                    
                    // Gender Card
                    if let gender = userData["gender"] as? String, !gender.isEmpty {
                        EnhancedInfoCard(
                            icon: "person.crop.circle.fill",
                            iconColor: .purple,
                            iconBackground: .purple.opacity(0.1),
                            title: "Gender", 
                            value: gender.capitalized,
                            screenWidth: screenWidth
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
                            isLargeText: true,
                            screenWidth: screenWidth
                        )
                    }
                    
                    // Attracted To Card
                    if let attractedTo = userData["attractedTo"] as? String, !attractedTo.isEmpty {
                        EnhancedInfoCard(
                            icon: "heart.fill",
                            iconColor: .pink,
                            iconBackground: .pink.opacity(0.1),
                            title: "Attracted to",
                            value: attractedTo.capitalized,
                            screenWidth: screenWidth
                        )
                    }
                    
                    // Instagram Card
                    if let handle = userData["instagramHandle"] as? String, !handle.isEmpty {
                        EnhancedInfoCard(
                            icon: "camera.fill",
                            iconColor: .purple,
                            iconBackground: .purple.opacity(0.1),
                            title: "Instagram",
                            value: handle.hasPrefix("@") ? handle : "@\(handle)",
                            screenWidth: screenWidth
                        )
                    }
                }
                
                // Enhanced Edit Profile Button - Responsive sizing
                Button(action: {
                    Haptics.lightImpact()
                    showEditProfile = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: max(18, ageFontSize), weight: .semibold))
                        Text("Edit Profile")
                            .font(.system(size: max(16, ageFontSize * 0.9), weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, max(16, dynamicVerticalSpacing * 0.7))
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
                
                // Dynamic bottom spacing based on screen height
                Spacer(minLength: max(40, screenHeight * 0.1))
            }
            .padding(.horizontal, dynamicHorizontalPadding)
            .padding(.top, dynamicVerticalSpacing)
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
    let screenWidth: CGFloat
    
    init(icon: String, iconColor: Color, iconBackground: Color, title: String, value: String, isLargeText: Bool = false, screenWidth: CGFloat) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.title = title
        self.value = value
        self.isLargeText = isLargeText
        self.screenWidth = screenWidth
    }
    
    var body: some View {
        HStack(spacing: max(12, screenWidth * 0.04)) {
            // Enhanced icon - Responsive size
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(
                        width: max(40, screenWidth * 0.12),
                        height: max(40, screenWidth * 0.12)
                    )
                
                Image(systemName: icon)
                    .font(.system(
                        size: max(18, screenWidth * 0.055),
                        weight: .semibold
                    ))
                    .foregroundColor(iconColor)
            }
            
            // Content - Responsive typography
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(
                        size: max(12, screenWidth * 0.032),
                        weight: .medium,
                        design: .rounded
                    ))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Text(value)
                    .font(.system(
                        size: isLargeText ? max(14, screenWidth * 0.04) : max(16, screenWidth * 0.045),
                        weight: .semibold,
                        design: .rounded
                    ))
                    .foregroundColor(.primary)
                    .lineLimit(isLargeText ? 4 : 2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.8) // Allow text to scale down if needed
            }
            
            Spacer()
        }
        .padding(.horizontal, max(16, screenWidth * 0.05))
        .padding(.vertical, max(12, screenWidth * 0.04))
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