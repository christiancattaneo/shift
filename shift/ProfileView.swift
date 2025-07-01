import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userSession = FirebaseUserSession.shared
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var userData: [String: Any] = [:]
    @State private var profileImageUrl: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeaderSection
                    
                    // Profile Content
                    if isLoading {
                        loadingSection
                    } else {
                        profileContentSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshProfile()
            }
        }
        .onAppear {
            loadUserProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userData: userData, profileImageUrl: profileImageUrl)
        }
    }
    
    // MARK: - UI Components
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            profileImageView
            
            // User Name and Age
            VStack(spacing: 8) {
                Text(getDisplayName())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let age = userData["age"] as? Int {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text("\(age) years old")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var profileImageView: some View {
        Group {
            if let imageUrl = profileImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        profileImagePlaceholder(isLoading: true)
                            .onAppear {
                                print("🖼️ PROFILE: Starting to load image from: \(imageUrl)")
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                            .onAppear {
                                print("✅ PROFILE: Image loaded successfully from: \(imageUrl)")
                            }
                    case .failure(let error):
                        profileImagePlaceholder(isLoading: false)
                            .onAppear {
                                print("❌ PROFILE: Image failed to load from: \(imageUrl)")
                                print("❌ PROFILE: Error details: \(error.localizedDescription)")
                            }
                    @unknown default:
                        profileImagePlaceholder(isLoading: false)
                            .onAppear {
                                print("⚠️ PROFILE: Unknown image loading phase for: \(imageUrl)")
                            }
                    }
                }
            } else {
                profileImagePlaceholder(isLoading: false)
                    .onAppear {
                        print("❌ PROFILE: No profile image URL available")
                    }
            }
        }
    }
    
    private func profileImagePlaceholder(isLoading: Bool) -> some View {
        ZStack {
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
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 4)
                )
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
            
            if isLoading {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    
                    Text(getDisplayName().prefix(1).uppercased())
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profile...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var profileContentSection: some View {
        VStack(spacing: 20) {
            if hasProfileData() {
                profileInfoSection
            } else {
                emptyProfileSection
            }
        }
    }
    
    private var profileInfoSection: some View {
        VStack(spacing: 16) {
            // Location
            if let city = userData["city"] as? String, !city.isEmpty {
                InfoCardView(
                    icon: "mappin.and.ellipse",
                    title: "Location",
                    value: city,
                    iconColor: .blue
                )
            }
            
            // Gender
            if let gender = userData["gender"] as? String, !gender.isEmpty {
                InfoCardView(
                    icon: "person.fill",
                    title: "Gender",
                    value: gender.capitalized,
                    iconColor: .purple
                )
            }
            
            // Approach Tip
            if let approachTip = userData["howToApproachMe"] as? String, !approachTip.isEmpty {
                InfoCardView(
                    icon: "lightbulb.fill",
                    title: "Best way to approach me",
                    value: approachTip,
                    iconColor: .orange
                )
            }
            
            // Attracted To
            if let attractedTo = userData["attractedTo"] as? String, !attractedTo.isEmpty {
                InfoCardView(
                    icon: "heart.fill",
                    title: "Looking for",
                    value: attractedTo.capitalized,
                    iconColor: .pink
                )
            }
            
            // Instagram Handle
            if let handle = userData["instagramHandle"] as? String, !handle.isEmpty {
                InfoCardView(
                    icon: "camera.fill",
                    title: "Instagram",
                    value: handle.hasPrefix("@") ? handle : "@\(handle)",
                    iconColor: .purple
                )
            }
            
            // Profile Completeness
            profileCompletenessCard
        }
    }
    
    private var emptyProfileSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("Complete Your Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Add details to help others connect with you and discover compatible matches.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 32)
    }
    
    private var profileCompletenessCard: some View {
        let completeness = calculateProfileCompleteness()
        let percentage = Int(completeness * 100)
        
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile Completeness")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("\(percentage)% complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * completeness, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 1.0), value: completeness)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Edit Profile Button
            Button(action: {
                Haptics.lightImpact()
                showEditProfile = true
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.headline)
                    Text(hasProfileData() ? "Edit Profile" : "Complete Profile")
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
            
            // Sign Out Button
            Button(action: {
                Haptics.lightImpact()
                userSession.signOut()
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                    Text("Sign Out")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
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
    
    private func hasProfileData() -> Bool {
        let city = userData["city"] as? String ?? ""
        let age = userData["age"] as? Int
        let gender = userData["gender"] as? String ?? ""
        
        return !city.isEmpty && age != nil && !gender.isEmpty
    }
    
    private func calculateProfileCompleteness() -> Double {
        var completenessScore: Double = 0.0
        let totalFields: Double = 7.0
        
        // Profile image
        if profileImageUrl != nil && !profileImageUrl!.isEmpty {
            completenessScore += 1.0
        }
        
        // Age
        if userData["age"] as? Int != nil {
            completenessScore += 1.0
        }
        
        // City
        if let city = userData["city"] as? String, !city.isEmpty {
            completenessScore += 1.0
        }
        
        // Gender
        if let gender = userData["gender"] as? String, !gender.isEmpty {
            completenessScore += 1.0
        }
        
        // Approach tip
        if let tip = userData["howToApproachMe"] as? String, !tip.isEmpty {
            completenessScore += 1.0
        }
        
        // Attracted to
        if let attractedTo = userData["attractedTo"] as? String, !attractedTo.isEmpty {
            completenessScore += 1.0
        }
        
        // Instagram handle
        if let handle = userData["instagramHandle"] as? String, !handle.isEmpty {
            completenessScore += 1.0
        }
        
        return completenessScore / totalFields
    }
}

// MARK: - Supporting Views

struct InfoCardView: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

#Preview {
    ProfileView()
} 