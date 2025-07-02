import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

// MARK: - Cached AsyncImage Component
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    @State private var loadingFailed = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        loadingFailed = false
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    cachedImage = uiImage
                    loadingFailed = false
                } else {
                    loadingFailed = true
                    print("🖼️ Failed to load image from: \(url)")
                }
            }
        }.resume()
    }
}

struct MembersView: View {
    @StateObject private var membersService = FirebaseMembersService.shared
    @EnvironmentObject private var userSession: FirebaseUserSession
    
    @State private var searchText = ""
    @State private var selectedFilter = "Compatible"
    @State private var displayedMembers: [FirebaseMember] = []
    @State private var filteredMembers: [FirebaseMember] = []
    @State private var allSearchResults: [FirebaseMember] = []
    @State private var isLoadingMore = false
    @State private var isRefreshing = false
    @State private var isSearching = false
    @State private var selectedMember: FirebaseMember?
    @State private var showingDetail = false
    @State private var hasMoreMembers = true
    @State private var currentPage = 0
    
    // Debouncing for search
    @State private var searchTask: Task<Void, Never>?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    private let filters = ["Compatible", "Nearby", "Online"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search members...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { oldValue, newValue in
                            debouncedSearch()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filters, id: \.self) { filter in
                        FilterPill(
                            title: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                            filterMembersAsync()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            
            // Members Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(displayedMembers.enumerated()), id: \.element.id) { index, member in
                        MemberCardView(member: member)
                            .onTapGesture {
                                selectedMember = member
                                showingDetail = true
                            }
                            .onAppear {
                                if index == displayedMembers.count - 1 {
                                    loadMoreMembers()
                                }
                            }
                    }
                    
                    // Loading More Indicator
                    if isLoadingMore && hasMoreMembers {
                        LoadingMoreView()
                    }
                    
                    // Search indicator
                    if isSearching {
                        HStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching all members...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
            .refreshable {
                await refreshMembers()
            }
        }
        .navigationTitle("Members")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedMember) { member in
            NavigationView {
                MemberDetailView(member: member)
            }
        }
        .onAppear {
            membersService.fetchMembers()
            filterMembersAsync()
        }
        .onChange(of: membersService.members) { oldValue, newValue in
            filterMembersAsync()
        }
    }
    
    // MARK: - Debounced Search
    
    private func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
            if !Task.isCancelled {
                await MainActor.run {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // If search is empty, go back to normal filtering
                        allSearchResults = []
                        filterMembersAsync()
                    } else {
                        // Perform Firebase search across all members
                        performFirebaseSearch()
                    }
                }
            }
        }
    }
    
    // MARK: - Firebase Search Function
    
    private func performFirebaseSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            allSearchResults = []
            filterMembersAsync()
            return
        }
        
        isSearching = true
        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🔍 FIREBASE SEARCH: Searching for '\(searchTerm)' across all members...")
        
        // Use FirebaseMembersService to search all members
        membersService.searchMembers(query: searchTerm) { searchResults in
            DispatchQueue.main.async {
                self.isSearching = false
                self.allSearchResults = searchResults
                
                print("🔍 FIREBASE SEARCH: Found \(searchResults.count) results for '\(searchTerm)'")
                
                // Apply current filter to search results
                filterSearchResults()
            }
        }
    }
    
    private func filterSearchResults() {
        var filtered = allSearchResults
        
        // Exclude current user
        if let currentUserId = userSession.currentUser?.id {
            filtered = filtered.filter { $0.userId != currentUserId }
        }
        
        // Apply current filter logic
        switch selectedFilter {
        case "Compatible":
            filtered = applyCompatibilityFilter(to: filtered)
        case "Nearby":
            filtered = applyLocationFilter(to: filtered)
        case "Online":
            filtered = applyOnlineFilter(to: filtered)
        default:
            break
        }
        
        // Sort by compatibility
        filtered = rankMembersByCompatibility(filtered, currentUser: userSession.currentUser)
        
        // Update display
        filteredMembers = filtered
        displayedMembers = Array(filtered.prefix(10)) // Show first 10 search results
        
        print("🔍 SEARCH RESULTS: \(displayedMembers.count) members displayed from \(filteredMembers.count) filtered search results")
    }
    
    // MARK: - Filtering Logic (Now Async)
    
    private func filterMembersAsync() {
        Task {
            await filterMembers()
        }
    }
    
    @MainActor
    private func filterMembers() async {
        // Skip if we're in search mode
        if !allSearchResults.isEmpty {
            return
        }
        
        print("🔍 Filtering \(membersService.members.count) members for user: \(userSession.currentUser?.firstName ?? "unknown")")
        
        let allMembers = membersService.members
        var filtered = allMembers
        let beforeFilter = filtered.count
        
        // Exclude current user
        if let currentUserId = userSession.currentUser?.id {
            filtered = filtered.filter { $0.userId != currentUserId }
        }
        
        print("🔍 After user exclusion: \(filtered.count) members (excluded \(beforeFilter - filtered.count))")
        
        // Apply filter-specific logic
        switch selectedFilter {
        case "Compatible":
            filtered = applyCompatibilityFilter(to: filtered)
        case "Nearby":
            filtered = applyLocationFilter(to: filtered)
        case "Online":
            filtered = applyOnlineFilter(to: filtered)
        default:
            break
        }
        
        print("🔍 After '\(selectedFilter)' filter: \(filtered.count) members (excluded \(beforeFilter - filtered.count))")
        
        // Sort members intelligently  
        filtered = rankMembersByCompatibility(filtered, currentUser: userSession.currentUser)
        
        // Reset pagination
        currentPage = 0
        hasMoreMembers = filtered.count > 10
        
        // Update both arrays and reset display
        filteredMembers = filtered
        displayedMembers = Array(filtered.prefix(10)) // Start with 10 members
        
        print("🎯 Final result: \(displayedMembers.count) members displayed from \(filteredMembers.count) total filtered")
    }
    
    private func loadMoreMembers() {
        guard !isLoadingMore && hasMoreMembers else { 
            print("📱 Cannot load more: isLoadingMore=\(isLoadingMore), hasMoreMembers=\(hasMoreMembers)")
            return 
        }
        
        let currentCount = displayedMembers.count
        let totalCount = filteredMembers.count
        
        guard currentCount < totalCount else { 
            print("📱 No more members to load: \(currentCount)/\(totalCount)")
            hasMoreMembers = false
            return 
        }
        
        isLoadingMore = true
        let batchSize = 10
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let endIndex = min(currentCount + batchSize, totalCount)
            guard currentCount < self.filteredMembers.count && endIndex <= self.filteredMembers.count else {
                print("❌ Array bounds error prevented: currentCount=\(currentCount), endIndex=\(endIndex), filteredMembers.count=\(self.filteredMembers.count)")
                self.isLoadingMore = false
                return
            }
            
            let nextBatch = Array(self.filteredMembers[currentCount..<endIndex])
            self.displayedMembers.append(contentsOf: nextBatch)
            self.currentPage += 1
            self.hasMoreMembers = self.displayedMembers.count < self.filteredMembers.count
            self.isLoadingMore = false
            
            print("📱 Loaded \(nextBatch.count) more members. Total displayed: \(self.displayedMembers.count)/\(totalCount), hasMore: \(self.hasMoreMembers)")
        }
    }
    
    private func refreshMembers() async {
        isRefreshing = true
        print("🔄 Refreshing members with fresh data...")
        
        // Reset search and pagination state
        allSearchResults = []
        currentPage = 0
        hasMoreMembers = true
        
        membersService.refreshMembers()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        await MainActor.run {
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                performFirebaseSearch()
            } else {
                filterMembersAsync()
            }
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
            // Profile Image - Rounded Square
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .empty:
                    loadingImageView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 160)
                        .clipped()
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure(_):
                    fallbackImageView
                @unknown default:
                    fallbackImageView
                }
            }
            
            // Member Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 4)
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .fixedSize()
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
                            .truncationMode(.tail)
                    }
                }
                
                if let tip = member.approachTip, !tip.isEmpty {
                    Text(tip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.tail)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
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
            
            VStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 160, height: 160)
        .clipped()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var fallbackImageView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
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
        .frame(width: 160, height: 160)
        .clipped()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                AsyncImage(url: member.profileImageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(maxWidth: .infinity, maxHeight: 500)
                            .frame(height: 500)
                            .clipped()
                            .overlay {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Loading...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 500)
                            .frame(height: 500)
                            .clipped()
                            .background(Color.gray.opacity(0.1))
                    case .failure(_):
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(maxWidth: .infinity, maxHeight: 500)
                            .frame(height: 500)
                            .clipped()
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
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(maxWidth: .infinity, maxHeight: 500)
                            .frame(height: 500)
                            .clipped()
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