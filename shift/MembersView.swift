import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct MembersView: View {
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @StateObject private var userSession = FirebaseUserSession.shared
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var selectedFilter = "All"
    @State private var filteredMembers: [FirebaseMember] = []
    @State private var currentUserPreferences: UserPreferences?
    
    // Lazy loading state - LOAD AT TOP
    @State private var displayedMembers: [FirebaseMember] = []
    @State private var isLoadingMore = false
    private let membersPerPage = 10 // Reduced to 10 members at a time
    
    private let filters = ["Compatible", "Nearby", "All", "Online"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Content Section
                if isRefreshing {
                    loadingView
                } else if displayedMembers.isEmpty {
                    emptyStateView
                } else {
                    membersGridView
                }
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshMembers()
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: membersService.members) {
            filterMembers()
        }
        .onChange(of: searchText) {
            filterMembers()
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search members...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filters, id: \.self) { filter in
                        FilterPill(
                            title: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                                filterMembers()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Results Counter
            if !displayedMembers.isEmpty {
                HStack {
                    Text("\(displayedMembers.count) members")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding compatible members...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
    
    private var membersGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(displayedMembers, id: \.uniqueID) { member in
                    NavigationLink(destination: MemberDetailView(member: member)) {
                        MemberCardView(member: member)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        if member.uniqueID == displayedMembers.last?.uniqueID {
                            loadMoreMembers()
                        }
                    }
                }
                
                // Loading More Indicator
                if isLoadingMore && filteredMembers.count > displayedMembers.count {
                    LoadingMoreView()
                        .gridCellColumns(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.3")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No members found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your filters or check back later for new members to discover")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Refresh") {
                Task {
                    await refreshMembers()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        loadUserPreferences()
        // FORCE REFRESH to fix cached Firebase Auth UIDs issue
        print("🔄 Forcing fresh member data to fix image URL issues...")
        membersService.refreshMembers()
        // Start with small batch
        displayedMembers = []
    }
    
    private func loadUserPreferences() {
        guard let currentUser = userSession.currentUser else { return }
        
        currentUserPreferences = UserPreferences(
            attractedTo: currentUser.attractedTo,
            city: currentUser.city,
            ageRange: (18, 50),
            maxDistance: 50
        )
    }
    
    private func filterMembers() {
        guard let currentUser = userSession.currentUser else {
            print("⚠️ No current user available for filtering - showing all members")
            // For debugging: Show all members when no current user
            filteredMembers = membersService.members
            displayedMembers = Array(membersService.members.prefix(membersPerPage))
            return
        }
        
        print("🔍 Filtering \(membersService.members.count) members for user: \(currentUser.firstName ?? "Unknown")")
        
        var filtered = membersService.members
        let originalCount = filtered.count
        
        // Exclude current user (less restrictive)
        filtered = filtered.filter { member in
            // Only exclude if we can definitively identify it's the same user
            if let memberId = member.id, let userId = currentUser.id, memberId == userId {
                return false
            }
            if let memberUserId = member.userId, let userId = currentUser.id, memberUserId == userId {
                return false
            }
            // Allow different people with same first name
            return true
        }
        
        print("🔍 After user exclusion: \(filtered.count) members (excluded \(originalCount - filtered.count))")
        
        // Apply search filter
        if !searchText.isEmpty {
            let beforeSearch = filtered.count
            filtered = filtered.filter { member in
                member.firstName.lowercased().contains(searchText.lowercased()) ||
                (member.city?.lowercased().contains(searchText.lowercased()) ?? false) ||
                (member.instagramHandle?.lowercased().contains(searchText.lowercased()) ?? false)
            }
            print("🔍 After search filter '\(searchText)': \(filtered.count) members (excluded \(beforeSearch - filtered.count))")
        }
        
        // Apply selected filter
        let beforeFilter = filtered.count
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
        print("🔍 After '\(selectedFilter)' filter: \(filtered.count) members (excluded \(beforeFilter - filtered.count))")
        
        // Sort members intelligently  
        filtered = rankMembersByCompatibility(filtered, currentUser: currentUser)
        
        filteredMembers = filtered
        // Start with just 5 members initially for better performance
        displayedMembers = Array(filtered.prefix(5))
        
        print("🎯 Final result: \(displayedMembers.count) members displayed from \(filteredMembers.count) total filtered")
    }
    
    private func loadMoreMembers() {
        guard !isLoadingMore else { return }
        
        let currentCount = displayedMembers.count
        let totalCount = filteredMembers.count
        
        guard currentCount < totalCount else { return }
        
        isLoadingMore = true
        let batchSize = 5 // Load 5 more members at a time
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let nextBatch = Array(filteredMembers[currentCount..<min(currentCount + batchSize, totalCount)])
            displayedMembers.append(contentsOf: nextBatch)
            isLoadingMore = false
            print("📱 Loaded \(nextBatch.count) more members. Total displayed: \(displayedMembers.count)/\(totalCount)")
        }
    }
    
    private func refreshMembers() async {
        isRefreshing = true
        print("🔄 Refreshing members with fresh data...")
        membersService.refreshMembers()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            displayedMembers = [] // Clear displayed members first
            filterMembers()
            isRefreshing = false
            print("✅ Refresh complete: \(displayedMembers.count) members loaded")
        }
    }
    
    // MARK: - Filtering Logic
    
    private func applyCompatibilityFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        guard let currentUser = userSession.currentUser else {
            return rankMembersByCompatibility(members, currentUser: nil)
        }
        
        let userAttractedTo = currentUser.attractedTo?.lowercased() ?? ""
        
        let filtered = members.filter { member in
            if userAttractedTo.isEmpty || userAttractedTo == "everyone" || userAttractedTo == "anyone" {
                return true
            }
            
            let memberGender = member.gender?.lowercased() ?? ""
            return checkGenderCompatibility(userAttractedTo: userAttractedTo, memberGender: memberGender)
        }
        
        return rankMembersByCompatibility(filtered, currentUser: currentUser)
    }
    
    private func checkGenderCompatibility(userAttractedTo: String?, memberGender: String?) -> Bool {
        guard let attractedTo = userAttractedTo?.lowercased() else { return true }
        guard let gender = memberGender?.lowercased() else { return true }
        
        switch attractedTo {
        case "women", "woman", "female":
            return gender.contains("woman") || gender.contains("female")
        case "men", "man", "male":
            return gender.contains("man") || gender.contains("male")
        case "everyone", "all", "anyone", "both":
            return true
        default:
            return true
        }
    }
    
    private func applyLocationFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        guard let currentUser = userSession.currentUser,
              let userCity = currentUser.city?.lowercased() else {
            return members
        }
        
        return members.filter { member in
            guard let memberCity = member.city?.lowercased() else { return false }
            return memberCity.contains(userCity) || userCity.contains(memberCity)
        }
    }
    
    private func applyOnlineFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        // For now, return all members for "Online" filter to debug
        // Later we can implement proper online status tracking
        print("🔍 Online filter: showing all \(members.count) members (online status not implemented)")
        return members
    }
    
    private func rankMembersByCompatibility(_ members: [FirebaseMember], currentUser: FirebaseUser?) -> [FirebaseMember] {
        guard let currentUser = currentUser else {
            return members.sorted { member1, member2 in
                let score1 = calculateProfileCompleteness(member1)
                let score2 = calculateProfileCompleteness(member2)
                return score1 > score2
            }
        }
        
        return members.sorted { member1, member2 in
            let score1 = calculateCompatibilityScore(member1, with: currentUser)
            let score2 = calculateCompatibilityScore(member2, with: currentUser)
            return score1 > score2
        }
    }
    
    private func calculateCompatibilityScore(_ member: FirebaseMember, with currentUser: FirebaseUser) -> Double {
        var score: Double = 0.0
        
        // Profile completeness (0-30 points)
        score += calculateProfileCompleteness(member) * 30
        
        // Age compatibility (0-25 points)
        if let memberAge = member.age, let userAge = currentUser.age {
            let ageDiff = abs(memberAge - userAge)
            let ageScore = max(0, 25 - Double(ageDiff))
            score += ageScore
        }
        
        // Location compatibility (0-20 points)
        if let memberCity = member.city?.lowercased(),
           let userCity = currentUser.city?.lowercased() {
            if memberCity == userCity {
                score += 20
            } else if memberCity.contains(userCity) || userCity.contains(memberCity) {
                score += 15
            }
        }
        
        // Attraction compatibility (0-15 points)
        if let userAttractedTo = currentUser.attractedTo?.lowercased(),
           let memberGender = member.gender?.lowercased() {
            if checkGenderCompatibility(userAttractedTo: userAttractedTo, memberGender: memberGender) {
                score += 15
            }
        }
        
        // Profile activity indicators (0-10 points)
        if member.instagramHandle != nil && !member.instagramHandle!.isEmpty {
            score += 5
        }
        if member.approachTip != nil && !member.approachTip!.isEmpty {
            score += 5
        }
        
        return score
    }
    
    private func calculateProfileCompleteness(_ member: FirebaseMember) -> Double {
        var completenessScore: Double = 0.0
        let totalFields: Double = 6.0
        
        // Images are always available via UUID-based URLs (profiles/{documentId}.jpg)
        // so we give credit for profile images to all users with valid document IDs
        if member.id != nil && !member.id!.isEmpty {
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

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct LoadingMoreView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading more...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 60)
    }
}

// MARK: - Enhanced Member Card View

struct MemberCardView: View {
    let member: FirebaseMember

    var body: some View {
        VStack(spacing: 0) {
            // Profile Image with consistent sizing
            CachedAsyncImage(url: member.profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } placeholder: {
                loadingImageView
            }
            
            // Member Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let city = member.city {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let tip = member.approachTip, !tip.isEmpty {
                    Text(tip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var loadingImageView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(maxWidth: .infinity, maxHeight: 200)
            .aspectRatio(1, contentMode: .fill)
            
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var fallbackImageView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.6))
                Text(member.firstName.prefix(1).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
    }
}

// MARK: - Supporting Structures

struct UserPreferences {
    let attractedTo: String?
    let city: String?
    let ageRange: (min: Int, max: Int)
    let maxDistance: Int
}

// MARK: - Member Detail View
struct MemberDetailView: View {
    let member: FirebaseMember
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile Image
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(url: member.profileImageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 500)
                            .clipped()
                    } placeholder: {
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
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray.opacity(0.6))
                                    Text(member.firstName.prefix(1).uppercased())
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(.gray.opacity(0.8))
                                }
                            }
                    }
                }
                
                // Member Information
                VStack(spacing: 24) {
                    // Name and Age
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.firstName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let age = member.age {
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
                    
                    // Location
                    if let city = member.city {
                        HStack(spacing: 8) {
                            Image(systemName: "location")
                                .font(.title2)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Location")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(city)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // Approach Tip
                    if let approachTip = member.approachTip, !approachTip.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb")
                                .font(.title2)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tip to Approach Me")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(approachTip)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // Attraction Preferences
                    if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.title2)
                                .foregroundColor(.pink)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Attracted to")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(attractedTo)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    // Instagram Handle
                    if let instagramHandle = member.instagramHandle, !instagramHandle.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "camera")
                                .font(.title2)
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instagram")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("@\(instagramHandle)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .navigationTitle(member.firstName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .background(Color(.systemBackground))
    }
}

#Preview {
    MembersView()
} 