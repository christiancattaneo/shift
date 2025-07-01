import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userSession = FirebaseUserSession.shared
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @State private var userMember: FirebaseMember?
    @State private var isLoading = true
    @State private var currentUserImageUrl: String?
    @State private var showEditProfile = false
    
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
            loadUserMemberProfile()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(userMember: userMember)
        }
    }
    
    // MARK: - UI Components
    
    private var profileHeaderSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            profileImageView
            
            // User Name and Age
            VStack(spacing: 8) {
                Text(userSession.currentUser?.firstName ?? "Unknown User")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let userMember = userMember, let age = userMember.age {
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
            if let imageUrl = currentUserImageUrl, !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        profileImagePlaceholder(isLoading: true)
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
                    case .failure(_):
                        profileImagePlaceholder(isLoading: false)
                    @unknown default:
                        profileImagePlaceholder(isLoading: false)
                    }
                }
            } else if let legacyPhoto = userSession.currentUser?.profilePhoto, !legacyPhoto.isEmpty {
                AsyncImage(url: URL(string: legacyPhoto)) { phase in
                    switch phase {
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
                    default:
                        profileImagePlaceholder(isLoading: false)
                    }
                }
            } else {
                profileImagePlaceholder(isLoading: false)
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
                    
                    if let firstName = userSession.currentUser?.firstName {
                        Text(firstName.prefix(1).uppercased())
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
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
            if let userMember = userMember {
                profileInfoSection(userMember)
            } else {
                emptyProfileSection
            }
        }
    }
    
    private func profileInfoSection(_ member: FirebaseMember) -> some View {
        VStack(spacing: 16) {
            // Location
            if let city = member.city {
                InfoCardView(
                    icon: "mappin.and.ellipse",
                    title: "Location",
                    value: city,
                    iconColor: .blue
                )
            }
            
            // Approach Tip
            if let approachTip = member.approachTip, !approachTip.isEmpty {
                InfoCardView(
                    icon: "lightbulb.fill",
                    title: "Best way to approach me",
                    value: approachTip,
                    iconColor: .orange
                )
            }
            
            // Attracted To
            if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                InfoCardView(
                    icon: "heart.fill",
                    title: "Looking for",
                    value: attractedTo.capitalized,
                    iconColor: .pink
                )
            }
            
            // Instagram Handle
            if let handle = member.instagramHandle, !handle.isEmpty {
                InfoCardView(
                    icon: "camera.fill",
                    title: "Instagram",
                    value: handle.hasPrefix("@") ? handle : "@\(handle)",
                    iconColor: .purple
                )
            }
            
            // Profile Completeness
            profileCompletenessCard(member)
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
    
    private func profileCompletenessCard(_ member: FirebaseMember) -> some View {
        let completeness = calculateProfileCompleteness(member)
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
                    Text(userMember == nil ? "Complete Profile" : "Edit Profile")
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
    
    private func loadUserMemberProfile() {
        guard let currentUser = userSession.currentUser else {
            isLoading = false
            return
        }
        
        Task {
            await loadCurrentUserImageUrl()
        }
        
        membersService.fetchMembers()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let userId = currentUser.id {
                userMember = membersService.members.first { member in
                    member.id == userId || member.userId == userId
                }
            }
            
            if userMember == nil {
                userMember = membersService.members.first { member in
                    member.firstName.lowercased() == currentUser.firstName?.lowercased()
                }
            }
            
            if let userMember = userMember, currentUserImageUrl == nil {
                currentUserImageUrl = userMember.profileImageUrl ?? userMember.firebaseImageUrl
            }
            
            isLoading = false
        }
    }
    
    private func loadCurrentUserImageUrl() async {
        guard let currentUser = userSession.currentUser,
              let userId = currentUser.id else { return }
        
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                let data = document.data()
                let profileImageUrl = data?["profileImageUrl"] as? String
                let firebaseImageUrl = data?["firebaseImageUrl"] as? String
                let profilePhoto = data?["profilePhoto"] as? String
                
                await MainActor.run {
                    currentUserImageUrl = profileImageUrl ?? firebaseImageUrl ?? profilePhoto
                }
            }
        } catch {
            print("Error loading user document: \(error)")
        }
    }
    
    private func refreshProfile() async {
        isLoading = true
        
        await loadCurrentUserImageUrl()
        membersService.refreshMembers()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            loadUserMemberProfile()
        }
    }
    
    private func calculateProfileCompleteness(_ member: FirebaseMember) -> Double {
        var completenessScore: Double = 0.0
        let totalFields: Double = 6.0
        
        if member.profileImageUrl != nil || member.firebaseImageUrl != nil {
            completenessScore += 1.0
        }
        if member.age != nil {
            completenessScore += 1.0
        }
        if member.city != nil && !member.city!.isEmpty {
            completenessScore += 1.0
        }
        if member.gender != nil && !member.gender!.isEmpty {
            completenessScore += 1.0
        }
        if member.approachTip != nil && !member.approachTip!.isEmpty {
            completenessScore += 1.0
        }
        if member.instagramHandle != nil && !member.instagramHandle!.isEmpty {
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