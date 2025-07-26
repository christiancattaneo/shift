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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var searchText = ""
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
    @State private var showSubscriptionModal = false
    
    // Debouncing for search
    @State private var searchTask: Task<Void, Never>?
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    // Computed property to break up complex expression
    private var membersWithTips: [FirebaseMember] {
        displayedMembers.filter { $0.approachTip != nil && !$0.approachTip!.isEmpty }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search compatible members...", text: $searchText)
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
            .padding(.bottom, 16)
            
            // Members Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(displayedMembers.enumerated()), id: \.offset) { index, member in
                        MemberCardView(member: member)
                            .onTapGesture {
                                // Check subscription status before showing details
                                if subscriptionManager.isSubscribed {
                                    selectedMember = member
                                    showingDetail = true
                                } else {
                                    showSubscriptionModal = true
                                }
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
                            Text("Searching compatible members...")
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
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionModalView()
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
        
        // SEARCH MODE: Only exclude current user, NO compatibility filters
        if let currentUser = userSession.currentUser {
            let currentUserDocumentId = currentUser.id
            
            filtered = filtered.filter { member in
                // Exclude if document IDs match
                if let memberUserId = member.userId, let currentUserId = currentUserDocumentId {
                    if memberUserId == currentUserId {
                        return false
                    }
                }
                
                // Exclude if first names match (additional safety check)
                if let currentFirstName = currentUser.firstName,
                   member.firstName.lowercased() == currentFirstName.lowercased() {
                    return false
                }
                
                return true
            }
        }
        
        // SEARCH MODE: Sort by name relevance, NOT compatibility
        let searchTerm = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        filtered = filtered.sorted { member1, member2 in
            let name1 = member1.firstName.lowercased()
            let name2 = member2.firstName.lowercased()
            
            // Exact matches first
            let exactMatch1 = name1 == searchTerm
            let exactMatch2 = name2 == searchTerm
            if exactMatch1 != exactMatch2 {
                return exactMatch1
            }
            
            // Prefix matches next
            let prefixMatch1 = name1.hasPrefix(searchTerm)
            let prefixMatch2 = name2.hasPrefix(searchTerm)
            if prefixMatch1 != prefixMatch2 {
                return prefixMatch1
            }
            
            // Then alphabetical by name
            return name1 < name2
        }
        
        // Update display - NO compatibility filtering in search mode
        filteredMembers = filtered
        displayedMembers = Array(filtered.prefix(20)) // Show more search results (20 instead of 10)
        
        print("🔍 SEARCH RESULTS: \(displayedMembers.count) total members displayed from \(filteredMembers.count) search results (NO compatibility filters)")
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
        
        print("🔍 Finding compatible members from \(membersService.members.count) total members for user: \(userSession.currentUser?.firstName ?? "unknown")")
        
        let allMembers = membersService.members
        var filtered = allMembers
        
        // FIXED: Exclude current user properly
        if let currentUser = userSession.currentUser {
            let currentUserDocumentId = currentUser.id
            
            filtered = filtered.filter { member in
                // Exclude if document IDs match
                if let memberUserId = member.userId, let currentUserId = currentUserDocumentId {
                    if memberUserId == currentUserId {
                        return false
                    }
                }
                
                // Exclude if first names match (additional safety check)
                if let currentFirstName = currentUser.firstName,
                   member.firstName.lowercased() == currentFirstName.lowercased() {
                    return false
                }
                
                // Exclude if emails match (additional safety check)
                if let memberUserId = member.userId {
                    // Check if the member's userId matches the current user's document ID
                    if memberUserId == currentUserDocumentId {
                        return false
                    }
                }
                
                return true
            }
        }
        
        
        // Apply filter-specific logic
        filtered = applyCompatibilityFilter(to: filtered)
        
        
        // Sort members intelligently  
        filtered = rankMembersByCompatibility(filtered, currentUser: userSession.currentUser)
        
        // Reset pagination
        currentPage = 0
        hasMoreMembers = filtered.count > 10 || membersService.hasMoreData || membersService.hasMoreCompatibleData
        
        // Update both arrays and reset display
        filteredMembers = filtered
        displayedMembers = Array(filtered.prefix(10)) // Start with 10 members
        
    }
    
    private func loadMoreMembers() {
        guard !isLoadingMore && hasMoreMembers else { 
            print("📱 Cannot load more: isLoadingMore=\(isLoadingMore), hasMoreMembers=\(hasMoreMembers)")
            return 
        }
        
        let currentCount = displayedMembers.count
        let totalCachedCount = filteredMembers.count
        
        print("📱 Loading more: current=\(currentCount), cached=\(totalCachedCount), hasFirebaseMore=\(membersService.hasMoreData)")
        
        // ENHANCED: First try to load from cached filtered members
        if currentCount < totalCachedCount {
            // Load from local filtered cache
            isLoadingMore = true
            let batchSize = 10
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let endIndex = min(currentCount + batchSize, totalCachedCount)
                guard currentCount < self.filteredMembers.count && endIndex <= self.filteredMembers.count else {
                    print("❌ Array bounds error prevented: currentCount=\(currentCount), endIndex=\(endIndex), filteredMembers.count=\(self.filteredMembers.count)")
                    self.isLoadingMore = false
                    return
                }
                
                let nextBatch = Array(self.filteredMembers[currentCount..<endIndex])
                self.displayedMembers.append(contentsOf: nextBatch)
                self.currentPage += 1
                self.isLoadingMore = false
                
                print("📱 Loaded \(nextBatch.count) more from cache. Total displayed: \(self.displayedMembers.count)/\(totalCachedCount)")
                
                // Check if we need to fetch more from Firebase
                if self.displayedMembers.count >= totalCachedCount - 5 && (self.membersService.hasMoreData || self.membersService.hasMoreCompatibleData) {
                    print("📱 Approaching end of cached data, fetching more from Firebase...")
                    self.fetchMoreFromFirebase()
                }
            }
        } else if membersService.hasMoreData || membersService.hasMoreCompatibleData {
            // Load more from Firebase when cache is exhausted
            print("📱 Cache exhausted, fetching more from Firebase...")
            fetchMoreFromFirebase()
        } else {
            // No more data available
            print("📱 No more data available from Firebase")
            hasMoreMembers = false
        }
    }
    
    private func fetchMoreFromFirebase() {
        guard !isLoadingMore else { return }
        
        isLoadingMore = true
        print("🔄 Fetching more compatible members from Firebase...")
        
        if let currentUser = userSession.currentUser {
            // Use the new paginated compatible members function
            membersService.fetchMoreCompatibleMembers(
                userGender: currentUser.gender,
                userAttractedTo: currentUser.attractedTo
            ) { newCompatibleMembers in
                DispatchQueue.main.async {
                    print("📱 Received \(newCompatibleMembers.count) new compatible members from Firebase")
                    
                    if !newCompatibleMembers.isEmpty {
                        // Enhanced duplicate detection with better logging
                        let existingUserIds = Set(self.membersService.members.compactMap { $0.userId })
                        let existingDocIds = Set(self.membersService.members.compactMap { $0.id })
                        
                        print("📱 DUPLICATE CHECK: Existing UserIds count: \(existingUserIds.count), Existing DocIds count: \(existingDocIds.count)")
                        print("📱 DUPLICATE CHECK: First few existing UserIds: \(Array(existingUserIds.prefix(3)))")
                        print("📱 DUPLICATE CHECK: First few new member UserIds: \(newCompatibleMembers.prefix(3).compactMap { $0.userId })")
                        print("📱 DUPLICATE CHECK: First few new member DocIds: \(newCompatibleMembers.prefix(3).compactMap { $0.id })")
                        
                        let uniqueNewMembers = newCompatibleMembers.filter { member in
                            // Check both userId and document id for duplicates
                            let userIdUnique = member.userId.map { !existingUserIds.contains($0) } ?? true
                            let docIdUnique = member.id.map { !existingDocIds.contains($0) } ?? true
                            
                            let isUnique = userIdUnique && docIdUnique
                            
                            if !isUnique {
                                print("📱 DUPLICATE: \(member.firstName) - userId: \(member.userId ?? "nil"), docId: \(member.id ?? "nil")")
                            }
                            
                            return isUnique
                        }
                        
                        print("📱 DUPLICATE CHECK: \(newCompatibleMembers.count) new members → \(uniqueNewMembers.count) unique")
                        
                        if !uniqueNewMembers.isEmpty {
                            // Add to service's members array
                            self.membersService.members.append(contentsOf: uniqueNewMembers)
                            print("📱 Added \(uniqueNewMembers.count) unique new members to cache (Total now: \(self.membersService.members.count))")
                            
                            // Re-filter with expanded dataset (this will include new members)
                            self.filterMembersAsync()
                        } else {
                            print("📱 All new members were duplicates")
                            // Even if duplicates, we should continue paginating to get different results
                            self.isLoadingMore = false
                        }
                    } else {
                        print("📱 No more compatible members available from Firebase")
                        // Try fallback: fetch users attracted to current user's gender
                        self.fetchFallbackMembers()
                    }
                }
            }
        } else {
            // Fallback: load general members if no current user
            print("📱 No current user, loading general members...")
            membersService.loadMoreMembers()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoadingMore = false
                self.filterMembersAsync()
            }
        }
    }
    
    private func refreshMembers() async {
        isRefreshing = true
        print("🔄 Refreshing compatible members with fresh data...")
        
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
            print("✅ Refresh complete: \(displayedMembers.count) compatible members loaded")
        }
    }
    
    // MARK: - Filtering Logic
    
    private func applyCompatibilityFilter(to members: [FirebaseMember]) -> [FirebaseMember] {
        guard let currentUser = userSession.currentUser else {
            return rankMembersByCompatibility(members, currentUser: nil)
        }
        
        // ENHANCED: If we have limited members or current user has specific preferences, 
        // fetch more targeted members from Firebase
        if members.count < 100 || currentUser.attractedTo != nil {
            fetchMoreCompatibleMembers()
        }
                
        let filtered = members.filter { otherUser in
            // STRICT: Both people MUST have complete gender and preference data
            let currentUserHasGender = currentUser.gender != nil && !currentUser.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let currentUserHasPreference = currentUser.attractedTo != nil && !currentUser.attractedTo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let otherUserHasGender = otherUser.gender != nil && !otherUser.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let otherUserHasPreference = otherUser.attractedTo != nil && !otherUser.attractedTo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
            // STRICT: Require ALL data to be present for compatibility tab
            if !currentUserHasGender || !currentUserHasPreference || !otherUserHasGender || !otherUserHasPreference {
                let _ = [
                    !currentUserHasGender ? "current user gender" : nil,
                    !currentUserHasPreference ? "current user preference" : nil,
                    !otherUserHasGender ? "\(otherUser.firstName) gender" : nil,
                    !otherUserHasPreference ? "\(otherUser.firstName) preference" : nil
                ].compactMap { $0 }
                return false
            }
            
            // Check mutual compatibility with strict logic
            let currentUserAttractedToOther = isStrictlyAttractedTo(userAttractedTo: currentUser.attractedTo!, personGender: otherUser.gender!)
            let otherUserAttractedToCurrent = isStrictlyAttractedTo(userAttractedTo: otherUser.attractedTo!, personGender: currentUser.gender!)
            
            let isMutuallyCompatible = currentUserAttractedToOther && otherUserAttractedToCurrent
            
            if isMutuallyCompatible {
                print("✅ COMPATIBLE: \(otherUser.firstName) - Current user (\(currentUser.gender!)) wants (\(currentUser.attractedTo!)) ← \(otherUser.firstName) (\(otherUser.gender!)) wants (\(otherUser.attractedTo!))")
            } else {
                print("❌ NOT COMPATIBLE: \(otherUser.firstName)")
                print("   - Current user (\(currentUser.gender!)) attracted to \(otherUser.firstName) (\(otherUser.gender!)): \(currentUserAttractedToOther)")
                print("   - \(otherUser.firstName) (\(otherUser.attractedTo!)) attracted to current user (\(currentUser.gender!)): \(otherUserAttractedToCurrent)")
            }
            
            return isMutuallyCompatible
        }
                
        // FALLBACK: If we have few or no strictly compatible members, add users attracted to current user
        if filtered.count < 10 && currentUser.gender != nil && !currentUser.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("🔄 FALLBACK: Adding users attracted to current user's gender (\(currentUser.gender!))")
            
            let fallbackMembers = members.filter { otherUser in
                // Skip if already in compatible list
                if filtered.contains(where: { $0.userId == otherUser.userId }) {
                    return false
                }
                
                // Require other user to have complete data
                let otherUserHasGender = otherUser.gender != nil && !otherUser.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let otherUserHasPreference = otherUser.attractedTo != nil && !otherUser.attractedTo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if !otherUserHasGender || !otherUserHasPreference {
                    return false
                }
                
                // Check if other user is attracted to current user's gender
                let otherUserAttractedToCurrent = isStrictlyAttractedTo(userAttractedTo: otherUser.attractedTo!, personGender: currentUser.gender!)
                
                if otherUserAttractedToCurrent {
                    print("🎯 FALLBACK MATCH: \(otherUser.firstName) (\(otherUser.attractedTo!)) is attracted to current user (\(currentUser.gender!))")
                    return true
                }
                
                return false
            }
            
            // Add fallback members to the filtered list
            let combinedMembers = filtered + fallbackMembers
            print("🔄 FALLBACK: Added \(fallbackMembers.count) fallback members. Total: \(combinedMembers.count)")
            
            return rankMembersByCompatibility(combinedMembers, currentUser: currentUser)
        }
        
        // STRICT FALLBACK: If still empty and we have many members, show no one
        if filtered.isEmpty && members.count > 50 {
            print("⚠️ STRICT FALLBACK: No compatible or interested members found")
            return []
        }
        
        return rankMembersByCompatibility(filtered, currentUser: currentUser)
    }
    
    // STRICT compatibility checking function
    private func isStrictlyAttractedTo(userAttractedTo: String, personGender: String) -> Bool {
        let attractedTo = userAttractedTo.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let gender = personGender.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("   🔍 Checking: attracted to '\(attractedTo)' vs gender '\(gender)'")
        
        // Check for female attraction
        if attractedTo.contains("female") || attractedTo.contains("woman") || attractedTo.contains("women") || attractedTo.contains("girl") {
            // FIXED: Use precise matching to avoid "female" containing "male" bug
            let isFemaleMatch = gender == "female" || gender == "woman" || gender == "girl" || gender == "f" ||
                               gender.hasPrefix("female") || gender.hasPrefix("woman") || gender.hasPrefix("girl")
            print("   🔍 Female check: \(isFemaleMatch)")
            return isFemaleMatch
        }
        
        // Check for male attraction
        if attractedTo.contains("male") || attractedTo.contains("man") || attractedTo.contains("men") || attractedTo.contains("guy") {
            // FIXED: Use precise matching to avoid "female" containing "male" bug
            let isMaleMatch = gender == "male" || gender == "man" || gender == "guy" || gender == "m" ||
                             (gender.hasPrefix("male") && !gender.hasPrefix("female")) ||
                             (gender.hasPrefix("man") && !gender.hasPrefix("woman")) ||
                             gender.hasPrefix("guy")
            print("   🔍 Male check: \(isMaleMatch)")
            return isMaleMatch
        }
        
        // Check for "everyone" or "all" or "both"
        if attractedTo.contains("everyone") || attractedTo.contains("all") || attractedTo.contains("both") {
            print("   🔍 Open to all: true")
            return true
        }
        
        print("   🔍 No match found: false")
        return false
    }
    
    private func fetchMoreCompatibleMembers() {
        guard let currentUser = userSession.currentUser else { return }
        
        print("🔍 ENHANCED: Fetching more compatible members for user attracted to '\(currentUser.attractedTo ?? "unknown")'")
        
        membersService.fetchCompatibleMembers(
            userGender: currentUser.gender,
            userAttractedTo: currentUser.attractedTo
        ) { compatibleMembers in
            DispatchQueue.main.async {
                // Merge with existing members without duplicates
                var allMembers = self.membersService.members
                let existingIds = Set(allMembers.compactMap { $0.userId })
                
                let newMembers = compatibleMembers.filter { member in
                    if let userId = member.userId {
                        return !existingIds.contains(userId)
                    }
                    return false
                }
                
                if !newMembers.isEmpty {
                    allMembers.append(contentsOf: newMembers)
                    self.membersService.members = allMembers
                    print("🔍 ENHANCED: Added \(newMembers.count) new compatible members (Total: \(allMembers.count))")
                    
                    // Re-filter with the expanded dataset
                    self.filterMembersAsync()
                }
            }
        }
    }
    
    private func fetchFallbackMembers() {
        guard let currentUser = userSession.currentUser,
              let currentUserGender = currentUser.gender,
              !currentUserGender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("📱 Cannot fetch fallback members: missing current user gender")
            self.hasMoreMembers = false
            self.isLoadingMore = false
            return
        }
        
        print("🔄 FALLBACK: Fetching users attracted to current user's gender (\(currentUserGender))")
        
        // Fetch users who might be attracted to the current user's gender
        membersService.fetchUsersAttractedTo(targetGender: currentUserGender) { fallbackMembers in
            DispatchQueue.main.async {
                if !fallbackMembers.isEmpty {
                    // Merge with existing members without duplicates
                    let existingIds = Set(self.membersService.members.compactMap { $0.userId })
                    let uniqueFallbackMembers = fallbackMembers.filter { member in
                        if let userId = member.userId {
                            return !existingIds.contains(userId)
                        }
                        return false
                    }
                    
                    if !uniqueFallbackMembers.isEmpty {
                        self.membersService.members.append(contentsOf: uniqueFallbackMembers)
                        print("🔄 FALLBACK: Added \(uniqueFallbackMembers.count) users interested in current user")
                        
                        // Re-filter with expanded dataset
                        self.filterMembersAsync()
                    } else {
                        print("📱 No new fallback members to add")
                        self.hasMoreMembers = false
                        self.isLoadingMore = false
                    }
                } else {
                    print("📱 No fallback members found")
                    self.hasMoreMembers = false
                    self.isLoadingMore = false
                }
            }
        }
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
        
        // Mutual attraction compatibility (0-25 points) - ENHANCED
        if areMutuallyCompatible(user: currentUser, otherUser: member) {
            score += 25  // Highest score for mutual compatibility
        } else {
            // Give partial credit based on attraction direction
            let currentUserAttractedToOther = isAttractedTo(userAttractedTo: currentUser.attractedTo, personGender: member.gender)
            let otherUserAttractedToCurrent = isAttractedTo(userAttractedTo: member.attractedTo, personGender: currentUser.gender)
            
            if currentUserAttractedToOther && otherUserAttractedToCurrent {
                // This should be caught by areMutuallyCompatible, but just in case
                score += 25
            } else if otherUserAttractedToCurrent {
                // Fallback member: they're attracted to current user (potential matches)
                score += 15  // Good fallback score
            } else if currentUserAttractedToOther {
                // Current user likes them but they don't like current user back
                score += 8   // Lower score since interest isn't mutual
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
    
    // MARK: - Mutual Compatibility Logic
    
    private func areMutuallyCompatible(user: FirebaseUser, otherUser: FirebaseMember) -> Bool {
        // STRICT: Only allow compatibility when both have complete data and are mutually attracted
        let currentUserHasGender = user.gender != nil && !user.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let currentUserHasPreference = user.attractedTo != nil && !user.attractedTo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let otherUserHasGender = otherUser.gender != nil && !otherUser.gender!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let otherUserHasPreference = otherUser.attractedTo != nil && !otherUser.attractedTo!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        // If either person is missing critical data, NOT compatible
        if !currentUserHasGender || !otherUserHasGender || !currentUserHasPreference || !otherUserHasPreference {
            return false
        }
        
        // Both have complete data - check mutual compatibility
        let currentUserAttractedToOther = isAttractedTo(userAttractedTo: user.attractedTo, personGender: otherUser.gender)
        let otherUserAttractedToCurrent = isAttractedTo(userAttractedTo: otherUser.attractedTo, personGender: user.gender)
        let isCompatible = currentUserAttractedToOther && otherUserAttractedToCurrent
        
        return isCompatible
    }
    
    private func isAttractedTo(userAttractedTo: String?, personGender: String?) -> Bool {
        // Clean and normalize attracted to preference
        let attractedTo = userAttractedTo?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Clean and normalize gender
        let gender = personGender?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // STRICT: Return false if no preference or gender specified
        if attractedTo.isEmpty {
            print("   - No preference specified: NOT COMPATIBLE")
            return false
        }
        
        if gender.isEmpty {
            print("   - No gender specified: NOT COMPATIBLE")
            return false 
        }
        
        // Check for open preferences - only explicit "everyone"/"all"/"both" type preferences
        if attractedTo == "everyone" || 
           attractedTo == "all" || 
           attractedTo == "anyone" || 
           attractedTo == "both" ||
           attractedTo == "all genders" ||
           attractedTo == "no preference" {
            print("   - Open to all: COMPATIBLE")
            return true
        }
        
        // Check for female attraction - person attracted to FEMALES
        if attractedTo.contains("women") || 
           attractedTo.contains("woman") || 
           attractedTo.contains("female") ||
           attractedTo.contains("girls") ||
           attractedTo.contains("girl") ||
           attractedTo.contains("fem") {
            // FIXED: Use precise matching to avoid "female" containing "male" bug
            let isPersonFemale = gender == "woman" || 
                               gender == "female" || 
                               gender == "girl" ||
                               gender == "fem" ||
                               gender == "f" ||
                               gender.hasPrefix("woman") ||
                               gender.hasPrefix("female") ||
                               gender.hasPrefix("girl")
            return isPersonFemale
        }
        
        // Check for male attraction - person attracted to MALES  
        if attractedTo.contains("men") || 
           attractedTo.contains("man") || 
           attractedTo.contains("male") ||
           attractedTo.contains("guys") ||
           attractedTo.contains("guy") ||
           attractedTo.contains("masc") {
            // FIXED: Use precise matching to avoid "female" containing "male" bug
            let isPersonMale = gender == "man" || 
                             gender == "male" || 
                             gender == "guy" ||
                             gender == "masc" ||
                             gender == "m" ||
                             (gender.hasPrefix("man") && !gender.hasPrefix("woman")) ||
                             (gender.hasPrefix("male") && !gender.hasPrefix("female")) ||
                             gender.hasPrefix("guy")
            return isPersonMale
        }
        
        // Check for non-binary and other gender identities
        if attractedTo.contains("non-binary") ||
           attractedTo.contains("nonbinary") ||
           attractedTo.contains("enby") ||
           attractedTo.contains("genderfluid") ||
           attractedTo.contains("genderqueer") ||
           attractedTo.contains("transgender") ||
           attractedTo.contains("trans") ||
           attractedTo.contains("queer") {
            let isPersonNonBinary = gender.contains("non-binary") ||
                                  gender.contains("nonbinary") ||
                                  gender.contains("enby") ||
                                  gender.contains("genderfluid") ||
                                  gender.contains("genderqueer") ||
                                  gender.contains("transgender") ||
                                  gender.contains("trans") ||
                                  gender.contains("queer")
            return isPersonNonBinary
        }
        
        print("   - No match found: NOT COMPATIBLE")
        return false
    }
    
    private func checkGenderCompatibility(userAttractedTo: String?, memberGender: String?) -> Bool {
        // Legacy function - keeping for backward compatibility but using new logic
        return isAttractedTo(userAttractedTo: userAttractedTo, personGender: memberGender)
    }
}

// MARK: - Supporting Views

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
                
                // Show approach tip when available - using exact same pattern as ProfileView
                if let tip = member.approachTip, !tip.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .truncationMode(.tail)
                    }
                    .padding(.top, 4)
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
                // Profile Image - Cropped with smart aspect ratio
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
                            .frame(maxWidth: 300, maxHeight: 400) // Constrain maximum size
                            .aspectRatio(4/5, contentMode: .fit) // Portrait aspect ratio
                            .clipped()
                            .cornerRadius(16) // Add rounded corners
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
                            .frame(maxWidth: 300, maxHeight: 400) // Constrain maximum size
                            .aspectRatio(4/5, contentMode: .fit) // Portrait aspect ratio
                            .clipped()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(16) // Add rounded corners
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4) // Add subtle shadow
                    case .failure(_):
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(maxWidth: 300, maxHeight: 400) // Constrain maximum size
                            .aspectRatio(4/5, contentMode: .fit) // Portrait aspect ratio
                            .clipped()
                            .cornerRadius(16) // Add rounded corners
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
                            .frame(maxWidth: 300, maxHeight: 400) // Constrain maximum size
                            .aspectRatio(4/5, contentMode: .fit) // Portrait aspect ratio
                            .clipped()
                            .cornerRadius(16) // Add rounded corners
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
                                Text(instagramHandle.hasPrefix("@") ? instagramHandle : "@\(instagramHandle)")
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