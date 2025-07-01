import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct MembersView: View {
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @StateObject private var userSession = FirebaseUserSession.shared
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedFilter = "Compatible"
    @State private var filteredMembers: [FirebaseMember] = []
    @State private var currentUserPreferences: UserPreferences?
    
    // Lazy loading state
    @State private var displayedMembers: [FirebaseMember] = []
    @State private var isLoadingMore = false
    private let membersPerPage = 20
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Clean Search and Filter Section
                VStack(spacing: 12) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search Members...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal, 20)
                    
                    // Filter Options
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(["Compatible", "Nearby", "All", "Online"], id: \.self) { filter in
                                Button(filter) {
                                    selectedFilter = filter
                                    filterMembers()
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(selectedFilter == filter ? Color.blue : Color.white)
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(25)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                // Members List
                if isRefreshing {
                    ProgressView("Loading compatible members...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedMembers.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 20) {
                            ForEach(displayedMembers, id: \.uniqueID) { member in
                                MemberCardView(member: member)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(0.8, contentMode: .fit)
                                    .onAppear {
                                        if member.uniqueID == displayedMembers.last?.uniqueID {
                                            loadMoreMembers()
                                        }
                                    }
                            }
                            
                            // Clean loading indicator
                            if isLoadingMore && filteredMembers.count > displayedMembers.count {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                    Text("Loading more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: 60)
                                .gridCellColumns(2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .refreshable {
                        await refreshMembers()
                    }
                }
            }
        }
        .navigationTitle("Members (\(displayedMembers.count))")
        .onAppear {
            loadUserPreferences()
            if membersService.members.isEmpty {
                membersService.fetchMembers()
            } else {
                filterMembers()
            }
        }
        .onChange(of: membersService.members) { _ in
            filterMembers()
        }
        .onChange(of: searchText) { _ in
            filterMembers()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 10) {
                Text("No compatible members found")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Try adjusting your filters or check back later")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                Task {
                    await refreshMembers()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - User Preferences Loading
    private func loadUserPreferences() {
        guard let currentUser = userSession.currentUser else { return }
        
        currentUserPreferences = UserPreferences(
            attractedTo: currentUser.attractedTo,
            city: currentUser.city,
            ageRange: (18, 50),
            maxDistance: 50
        )
    }
    
    // MARK: - Smart Filtering Based on Preferences
    private func filterMembers() {
        guard let currentUser = userSession.currentUser else {
            filteredMembers = []
            displayedMembers = []
            return
        }
        
        var filtered = membersService.members
        
        // Exclude the current user
        filtered = filtered.filter { member in
            member.id != currentUser.id && 
            member.userId != currentUser.id &&
            member.firstName.lowercased() != currentUser.firstName?.lowercased()
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { member in
                member.firstName.lowercased().contains(searchText.lowercased()) ||
                (member.city?.lowercased().contains(searchText.lowercased()) ?? false) ||
                (member.instagramHandle?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // Apply compatibility filters
        switch selectedFilter {
        case "Compatible":
            filtered = applyCompatibilityFilter(to: filtered)
        case "Nearby":
            filtered = applyLocationFilter(to: filtered)
        case "Online":
            filtered = applyOnlineFilter(to: filtered)
        default:
            break // "All" - no additional filtering
        }
        
        // Sort by compatibility score (members with images first, then by age/distance)
        filtered = filtered.sorted { member1, member2 in
            // Prioritize members with profile images
            let hasImage1 = member1.profileImageUrl != nil || member1.firebaseImageUrl != nil
            let hasImage2 = member2.profileImageUrl != nil || member2.firebaseImageUrl != nil
            
            if hasImage1 != hasImage2 {
                return hasImage1 // Members with images come first
            }
            
            // Then sort by age (closer to current user's age is better)
            if let currentAge = currentUser.age,
               let age1 = member1.age,
               let age2 = member2.age {
                let diff1 = abs(age1 - currentAge)
                let diff2 = abs(age2 - currentAge)
                return diff1 < diff2
            }
            
            // Finally, sort alphabetically
            return member1.firstName < member2.firstName
        }
        
        filteredMembers = filtered
        displayedMembers = Array(filtered.prefix(membersPerPage))
    }
    
    private func applyCompatibilityFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        guard let currentUser = userSession.currentUser,
              let userAttractedTo = currentUser.attractedTo?.lowercased() else {
            return members
        }
        
        return members.filter { member in
            // Check if current user is attracted to this member's gender
            let isUserAttractedToMember = checkGenderCompatibility(
                userAttractedTo: userAttractedTo,
                memberGender: member.gender
            )
            
            // Check if member is attracted to current user's gender
            let isMemberAttractedToUser = checkGenderCompatibility(
                userAttractedTo: member.attractedTo?.lowercased(),
                memberGender: currentUser.gender
            )
            
            return isUserAttractedToMember && isMemberAttractedToUser
        }
    }
    
    private func checkGenderCompatibility(userAttractedTo: String?, memberGender: String?) -> Bool {
        guard let attractedTo = userAttractedTo?.lowercased() else { return true }
        guard let gender = memberGender?.lowercased() else { return true }
        
        // Handle various attraction preferences
        switch attractedTo {
        case "women", "woman", "female":
            return gender.contains("woman") || gender.contains("female")
        case "men", "man", "male":
            return gender.contains("man") || gender.contains("male")
        case "everyone", "all", "anyone", "both":
            return true
        default:
            return true // If unclear, include them
        }
    }
    
    private func applyLocationFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        guard let currentUser = userSession.currentUser,
              let userCity = currentUser.city?.lowercased() else {
            return members
        }
        
        return members.filter { member in
            guard let memberCity = member.city?.lowercased() else { return false }
            
            // Same city or nearby area
            return memberCity.contains(userCity) || userCity.contains(memberCity)
        }
    }
    
    private func applyOnlineFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        // For now, return members who have been active recently or have complete profiles
        return members.filter { member in
            member.profileImageUrl != nil || member.firebaseImageUrl != nil
        }
    }
    
    // MARK: - Lazy Loading
    private func loadMoreMembers() {
        guard !isLoadingMore else { return }
        
        let currentCount = displayedMembers.count
        let totalCount = filteredMembers.count
        
        guard currentCount < totalCount else { return }
        
        isLoadingMore = true
        
        // Simulate loading delay for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let nextBatch = Array(filteredMembers[currentCount..<min(currentCount + membersPerPage, totalCount)])
            displayedMembers.append(contentsOf: nextBatch)
            isLoadingMore = false
        }
    }
    
    private func refreshMembers() async {
        isRefreshing = true
        membersService.refreshMembers()
        
        // Wait a moment for data to load
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            filterMembers()
            isRefreshing = false
        }
    }
}

// MARK: - User Preferences Structure
struct UserPreferences {
    let attractedTo: String?
    let city: String?
    let ageRange: (min: Int, max: Int)
    let maxDistance: Int // miles
}

// Aesthetic Card View for each member
struct MemberCardView: View {
    let member: FirebaseMember

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clean Profile Image
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 180)
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 35))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                case .failure(_):
                    ZStack {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(height: 180)
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 35))
                                .foregroundColor(.gray.opacity(0.6))
                            Text(member.firstName.prefix(1).uppercased())
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 180)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Name and Age
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                // City
                if let city = member.city, !city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Approach Tip (prioritized for dating context)
                if let approachTip = member.approachTip, !approachTip.isEmpty {
                    Text("💬 \(approachTip)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // Instagram Handle
                if let instagram = member.instagramHandle, !instagram.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("@\(instagram)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
                
                Spacer()
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .onTapGesture {
            // Navigate to member detail or send message
        }
    }
}

// MARK: - TEST IMAGE VIEW
struct TestFirebaseImageView: View {
    // Test with real images from all three Firebase Storage collections
    let profileImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/100_1751052272118.jpeg")
    let eventImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/event_images/127_1751052295829.png")
    let placeImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/place_images/10_1751052347060.jpeg")
    
    var body: some View {
        VStack(spacing: 10) {
            Text("🧪 FIREBASE IMAGE COLLECTION TEST")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack(spacing: 12) {
                // Profile image test (User ID: 100)
                VStack(spacing: 4) {
                    AsyncImage(url: profileImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .onAppear {
                                    print("✅ PROFILE IMAGE LOADED! (User ID: 100)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "person.crop.circle.fill.badge.xmark")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Profile image failed: \(error)")
                            }
                        @unknown default:
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("👤 Profile")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Event image test (Event ID: 127)
                VStack(spacing: 4) {
                    AsyncImage(url: eventImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onAppear {
                                    print("✅ EVENT IMAGE LOADED! (Event ID: 127)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Event image failed: \(error)")
                            }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("🎉 Event")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 127")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Place image test (Place ID: 10)
                VStack(spacing: 4) {
                    AsyncImage(url: placeImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    print("✅ PLACE IMAGE LOADED! (Place ID: 10)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "location.fill.viewfinder")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Place image failed: \(error)")
                            }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("📍 Place")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 10")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Testing real images from your migrated collections")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    MembersView()
} 