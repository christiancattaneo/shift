import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Array Extension for Batching
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Firebase User Session Management
class FirebaseUserSession: ObservableObject {
    static let shared = FirebaseUserSession()
    
    @Published var currentUser: FirebaseUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var isLoadingUserData = false  // Prevent redundant user data loads
    
    // Public access to Firebase Auth user
    var firebaseAuthUser: FirebaseAuth.User? {
        return auth.currentUser
    }
    
    private init() {
        // Listen for auth state changes
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.loadUserDataIfNeeded(uid: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isLoggedIn = false
                    self?.isLoadingUserData = false
                }
            }
        }
        
        // Check current auth state immediately
        checkCurrentAuthState()
    }
    
    private func checkCurrentAuthState() {
        if let currentUser = auth.currentUser {
            loadUserDataIfNeeded(uid: currentUser.uid)
        } else {
            isLoggedIn = false
        }
    }
    
    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    func signUp(email: String, password: String, firstName: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let uid = result?.user.uid else {
                    completion(false, "Failed to get user ID")
                    return
                }
                
                // Create user document in Firestore
                let newUser = FirebaseUser(
                    email: email,
                    firstName: firstName
                )
                
                self?.createUserDocument(user: newUser, uid: uid) { success, error in
                    completion(success, error)
                }
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔐 Starting signIn: Thread=MAIN")
        isLoading = true
        errorMessage = nil
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            print("🔐 SignIn auth response: Thread=BACKGROUND")
            
            DispatchQueue.main.async {
                print("🔐 Processing signIn response on main thread")
                self?.isLoading = false
                
                if let error = error {
                    print("🔐 SignIn error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                print("🔐 SignIn success")
                completion(true, nil)
            }
        }
    }
    
    func signOut() {
        print("🔐 Starting signOut: Thread=MAIN")
        
        do {
            try auth.signOut()
            print("🔐 SignOut success")
            currentUser = nil
            isLoggedIn = false
        } catch {
            print("🔐 SignOut error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func createUserDocument(user: FirebaseUser, uid: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔐 Creating user document: uid=\(uid), Thread=MAIN")
        
        do {
            try db.collection("users").document(uid).setData(from: user) { error in
                print("🔐 User document creation response: Thread=BACKGROUND")
                
                DispatchQueue.main.async {
                    print("🔐 Processing user document creation on main thread")
                    if let error = error {
                        print("🔐 User document creation error: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                    } else {
                        print("🔐 User document created successfully")
                        self.currentUser = user
                        self.isLoggedIn = true
                        completion(true, nil)
                    }
                }
            }
        } catch {
            print("🔐 User document creation encoding error: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
    
    private func loadUserDataIfNeeded(uid: String) {
        print("🔐 loadUserDataIfNeeded: uid=\(uid), isLoading=\(isLoadingUserData), Thread=MAIN")
        
        // Prevent redundant calls if already loading or user data already exists
        guard !isLoadingUserData else {
            print("📋 Skipping loadUserData - already in progress")
            return
        }
        
        // If we already have user data for this UID, don't reload
        if let currentUser = currentUser, currentUser.id == uid {
            print("📋 User data already loaded for UID: \(uid)")
            isLoggedIn = true
            return
        }
        
        isLoadingUserData = true
        print("📋 Loading user data for UID: \(uid)")
        
        // Get email from Firebase Auth to search by email (since document IDs are UUIDs after migration)
        guard let firebaseAuthUser = auth.currentUser,
              let userEmail = firebaseAuthUser.email else {
            print("❌ No email available for user lookup")
            isLoadingUserData = false
            errorMessage = "No email available"
            return
        }
        
        print("📧 Looking up user by email: \(userEmail)")
        
        // Load in background to prevent UI blocking
        print("🔐 Starting background user data fetch by email")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            print("🔐 Background user data fetch by email: Thread=BACKGROUND")
            
            self?.db.collection("users")
                .whereField("email", isEqualTo: userEmail)
                .limit(to: 1)
                .getDocuments { [weak self] querySnapshot, error in
                    print("🔐 User data fetch response: Thread=BACKGROUND")
                    
                    DispatchQueue.main.async {
                        print("🔐 Processing user data fetch response on main thread")
                        self?.isLoadingUserData = false
                        
                        if let error = error {
                            print("❌ Error loading user data: \(error.localizedDescription)")
                            self?.errorMessage = error.localizedDescription
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents,
                              let document = documents.first else {
                            print("❌ User document not found for email: \(userEmail)")
                            self?.errorMessage = "User document not found"
                            return
                        }
                        
                        do {
                            let user = try document.data(as: FirebaseUser.self)
                            print("✅ User data loaded successfully: \(user.firstName ?? "Unknown")")
                            print("✅ Document ID: \(document.documentID)")
                            
                            // Update the user object with the correct document ID
                            var updatedUser = user
                            updatedUser.id = document.documentID
                            
                            self?.currentUser = updatedUser
                            self?.isLoggedIn = true
                            print("🔐 Set isLoggedIn=true, should trigger UI update")
                        } catch {
                            print("❌ Error decoding user data: \(error.localizedDescription)")
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                }
        }
    }
    
    func updateUserProfile(_ user: FirebaseUser, completion: @escaping (Bool, String?) -> Void) {
        print("🔐 Updating user profile: Thread=MAIN")
        
        guard let uid = user.id else {
            print("🔐 Update profile error: Invalid user ID")
            completion(false, "Invalid user ID")
            return
        }
        
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true) { error in
                print("🔐 Update profile response: Thread=BACKGROUND")
                
                DispatchQueue.main.async {
                    print("🔐 Processing update profile response on main thread")
                    if let error = error {
                        print("🔐 Update profile error: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                    } else {
                        print("🔐 Update profile success")
                        self.currentUser = user
                        completion(true, nil)
                    }
                }
            }
        } catch {
            print("🔐 Update profile encoding error: \(error.localizedDescription)")
            completion(false, error.localizedDescription)
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Bool, String?) -> Void) {
        auth.sendPasswordReset(withEmail: email) { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    // MARK: - Email Link Authentication
    
    /// Send email link for passwordless authentication
    func sendSignInLink(email: String, completion: @escaping (Bool, String?) -> Void) {
        let actionCodeSettings = ActionCodeSettings()
        
        // IMPROVED: Use a more generic continue URL without email in query (some filters block this)
        actionCodeSettings.url = URL(string: "https://shift-12948.firebaseapp.com/emailSignIn")!
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID("com.christiancattaneo.shift")
        
        // ENHANCED: Add additional settings for better email compatibility
        actionCodeSettings.setAndroidPackageName("com.christiancattaneo.shift", 
                                                  installIfNotAvailable: false, 
                                                  minimumVersion: nil)
        
        // Store email locally before sending (so we don't need it in URL)
        UserDefaults.standard.set(email, forKey: "pendingEmailLink")
        
        auth.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error sending email link: \(error.localizedDescription)")
                    
                    // Enhanced error handling for college emails
                    var friendlyMessage = error.localizedDescription
                    
                    if error.localizedDescription.contains("invalid-email") {
                        friendlyMessage = "Please check your email address format"
                    } else if error.localizedDescription.contains("quota-exceeded") {
                        friendlyMessage = "Too many requests. Please try again in a few minutes"
                    } else if error.localizedDescription.contains("operation-not-allowed") {
                        friendlyMessage = "Email link authentication is temporarily unavailable"
                    } else {
                        // For college emails, provide specific guidance
                        if email.contains(".edu") || email.contains("student") || email.contains("college") || email.contains("university") {
                            friendlyMessage = "College emails may take longer or be filtered. Check your spam folder and try a personal email if issues persist"
                        }
                    }
                    
                    completion(false, friendlyMessage)
                } else {
                    print("✅ Email link sent successfully to \(email)")
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Verify if a link is an email sign-in link
    func isSignInLink(_ link: String) -> Bool {
        return auth.isSignIn(withEmailLink: link)
    }
    
    /// Complete sign-in with email link
    func signInWithEmailLink(email: String, link: String, completion: @escaping (Bool, String?) -> Void) {
        auth.signIn(withEmail: email, link: link) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Email link sign-in error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else if let user = result?.user {
                    print("✅ Email link sign-in successful: \(user.uid)")
                    // Clear stored email
                    UserDefaults.standard.removeObject(forKey: "pendingEmailLink")
                    // Load user data
                    self?.loadUserDataIfNeeded(uid: user.uid)
                    completion(true, nil)
                } else {
                    completion(false, "Unknown error occurred")
                }
            }
        }
    }
    
    /// Get stored email for pending email link
    func getPendingEmailLink() -> String? {
        return UserDefaults.standard.string(forKey: "pendingEmailLink")
    }
    
    func loadSavedUser() {
        print("🔄 loadSavedUser() called - checking Firebase Auth persistence...")
        print("🔄 loadSavedUser: Thread=MAIN")
        
        // Firebase Auth automatically handles persistence
        if let currentUser = auth.currentUser {
            print("📱 Firebase Auth found persisted user: \(currentUser.uid)")
            // Don't call loadUserData here - the auth state listener will handle it
            print("📱 Auth state listener will handle user data loading")
        } else {
            print("📱 No persisted Firebase Auth user found")
            isLoggedIn = false
        }
    }
}

// MARK: - Firebase Members Service
class FirebaseMembersService: ObservableObject {
    static let shared = FirebaseMembersService()
    
    private let db = Firestore.firestore()
    
    @Published var members: [FirebaseMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasFetched = false
    private var cachedMembers: [FirebaseMember] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 300 // 5 minutes cache
    
    // Pagination
    private var lastDocument: DocumentSnapshot?
    private var lastCompatibleDocument: DocumentSnapshot? // Separate pagination for compatible members
    @Published var hasMoreData = true
    @Published var hasMoreCompatibleData = true
    private let batchSize = 50 // Reduced from 500 to 50
    
    private init() {
        print("👥 FirebaseMembersService singleton initialized")
    }
    
    // Force refresh bypassing cache
    func refreshMembers() {
        print("🔄 Force refreshing members...")
        hasFetched = false
        cachedMembers = []
        cacheTimestamp = nil
        members = []
        lastDocument = nil
        lastCompatibleDocument = nil
        hasMoreData = true
        hasMoreCompatibleData = true
        fetchMembers()
    }
    
    func fetchMembers() {
        // Prevent redundant calls
        guard !isLoading else {
            print("📋 Skipping fetchMembers - already in progress")
            return
        }
        
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !cachedMembers.isEmpty {
            print("📋 Using cached members (\(cachedMembers.count) items)")
            members = cachedMembers
            return
        }
        
        print("🔄 Starting fetchMembers...")
        isLoading = true
        errorMessage = nil
        
        // Fetch in background to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // ENHANCED: Use multiple diverse queries to get better member variety
            let increasedLimit = max(100, self?.batchSize ?? 50) // Get more members
            
            var query: Query
            
            // Use different ordering strategies for better diversity
            if self?.lastDocument == nil {
                // First batch: Get recent users for active profiles
                query = self?.db.collection("users")
                    .whereField("firstName", isNotEqualTo: "")  // Only users with names
                    .order(by: "createdAt", descending: true) // Recent users first
                    .limit(to: increasedLimit) ?? self!.db.collection("users").limit(to: increasedLimit)
            } else {
                // Subsequent batches: Use document ID ordering for different results
                if let lastDoc = self?.lastDocument {
                    query = self?.db.collection("users")
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "updatedAt", descending: true) // Recently active users
                        .start(afterDocument: lastDoc)
                        .limit(to: increasedLimit) ?? self!.db.collection("users").limit(to: increasedLimit)
                } else {
                    // Fallback if no lastDocument
                    query = self?.db.collection("users")
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "updatedAt", descending: true)
                        .limit(to: increasedLimit) ?? self!.db.collection("users").limit(to: increasedLimit)
                }
            }
            
            query.getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.hasFetched = true
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("❌ Error fetching members: \(error.localizedDescription)")
                        
                        // Use cached data if available during error
                        if !(self?.cachedMembers.isEmpty ?? true) {
                            print("🔄 Using cached data during network error")
                            self?.members = self?.cachedMembers ?? []
                        } else {
                            // Load mock data as fallback
                            self?.members = self?.getMockMembers() ?? []
                        }
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        self?.members = []
                        return
                    }
                    
                    // Store last document for pagination
                    self?.lastDocument = documents.last
                    self?.hasMoreData = documents.count == (self?.batchSize ?? 50)
                    
                    // Process documents efficiently with minimal logging
                    let members = documents.compactMap { document -> FirebaseMember? in
                        do {
                            // First try to decode as FirebaseMember directly
                            if let member = try? document.data(as: FirebaseMember.self) {
                                return member
                            }
                            
                            // Fallback: decode as FirebaseUser and convert
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { 
                                return nil
                            }
                            
                            // MINIMAL LOGGING: Only log first 3 users for debugging
                            let shouldLog = (self?.members.count ?? 0) < 3
                            if shouldLog {
                                print("🔧 Converting user \(firstName) to member (ID: \(document.documentID))")
                            }
                            
                            let member = FirebaseMember(
                                userId: document.documentID, // Use document ID (UUID v4)
                                firstName: firstName,
                                lastName: user.fullName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,  // Map from Firestore field to property
                                instagramHandle: user.instagramHandle,
                                profileImage: nil, // No legacy URLs
                                profileImageUrl: nil, // No legacy URLs
                                firebaseImageUrl: nil, // No legacy URLs
                                bio: nil,
                                location: user.city,
                                interests: nil,
                                gender: user.gender,
                                relationshipGoals: nil,
                                dateJoined: user.createdAt,
                                status: nil,
                                isActive: true,
                                lastActiveDate: user.updatedAt,
                                isVerified: false,
                                verificationDate: nil,
                                subscriptionStatus: user.subscribed == true ? "active" : "inactive",
                                fcmToken: nil,
                                profilePhoto: nil,
                                profileImageName: nil
                            )
                            
                            // Debug: Log approach tip data
                            if let tip = member.approachTip, !tip.isEmpty {
                                print("💡 APPROACH TIP: \(member.firstName) has tip: '\(tip)'")
                            } else {
                                print("❌ APPROACH TIP: \(member.firstName) has no tip (raw howToApproachMe: '\(user.howToApproachMe ?? "nil")')")
                            }
                            
                            // ENHANCED DEBUG: Show the full conversion process
                            print("🔍 CONVERSION DEBUG: \(member.firstName)")
                            print("  - Original howToApproachMe: '\(user.howToApproachMe ?? "nil")'")
                            print("  - Converted approachTip: '\(member.approachTip ?? "nil")'")
                            print("  - Non-empty check: \(member.approachTip?.isEmpty == false)")
                            
                            return member
                        } catch {
                            // Minimal error logging
                            print("⚠️ Error decoding user \(document.documentID): \(error.localizedDescription)")
                            return nil
                        }
                    }
                    
                    // Update cache with new members
                    if self?.lastDocument == nil {
                        // First batch - replace cache
                        self?.cachedMembers = members
                        self?.members = members
                    } else {
                        // Additional batch - append to cache
                        self?.cachedMembers.append(contentsOf: members)
                        self?.members.append(contentsOf: members)
                    }
                    
                    self?.cacheTimestamp = Date()
                    
                    print("✅ Loaded \(members.count) members from \(documents.count) documents (Total: \(self?.members.count ?? 0))")
                }
            }
        }
    }
    
    // Load more members (pagination)
    func loadMoreMembers() {
        guard hasMoreData && !isLoading else {
            print("📋 No more members to load or already loading")
            return
        }
        
        print("🔄 Loading more members...")
        fetchMembers()
    }
    
    // MARK: - Fetch Compatible Members Function
    func fetchCompatibleMembers(userGender: String?, userAttractedTo: String?, completion: @escaping ([FirebaseMember]) -> Void) {
        guard let attractedTo = userAttractedTo?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !attractedTo.isEmpty else {
            print("🔍 COMPATIBILITY: No attraction preference specified, returning all members")
            completion(self.members)
            return
        }
        
        print("🔍 COMPATIBILITY: Fetching members for user attracted to '\(attractedTo)'")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var queries: [Query] = []
            
            // ENHANCED: More flexible gender queries with broader matching
            if attractedTo.contains("female") || attractedTo.contains("woman") || attractedTo.contains("women") || attractedTo.contains("girl") {
                // More comprehensive query for female-identifying people
                let femaleVariations = ["Female", "female", "Woman", "woman", "Girl", "girl", "F", "f", "fem", "Fem"]
                queries.append(
                    self?.db.collection("users")
                        .whereField("gender", in: femaleVariations)
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "updatedAt", descending: true)
                        .limit(to: 100) ?? self!.db.collection("users").limit(to: 100)
                )
            }
            
            if attractedTo.contains("male") || attractedTo.contains("man") || attractedTo.contains("men") || attractedTo.contains("guy") {
                // More comprehensive query for male-identifying people  
                let maleVariations = ["Male", "male", "Man", "man", "Guy", "guy", "M", "m", "masc", "Masc"]
                queries.append(
                    self?.db.collection("users")
                        .whereField("gender", in: maleVariations)
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "updatedAt", descending: true)
                        .limit(to: 100) ?? self!.db.collection("users").limit(to: 100)
                )
            }
            
            if attractedTo.contains("everyone") || attractedTo.contains("all") || attractedTo.contains("both") || attractedTo.contains("any") {
                // Query for all genders
                queries.append(
                    self?.db.collection("users")
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "updatedAt", descending: true)
                        .limit(to: 150) ?? self!.db.collection("users").limit(to: 150)
                )
            }
            
            // ENHANCED: If no specific queries, OR if we want to be more inclusive, add a general query
            if queries.isEmpty {
                print("🔍 COMPATIBILITY: No specific gender queries, fetching all members")
                queries.append(
                    self?.db.collection("users")
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "createdAt", descending: true)
                        .limit(to: 150) ?? self!.db.collection("users").limit(to: 150)
                )
            } else {
                // ADDITIONAL: Also add a fallback query without gender filtering
                // This ensures we get some results even if gender data is inconsistent
                queries.append(
                    self?.db.collection("users")
                        .whereField("firstName", isNotEqualTo: "")
                        .order(by: "createdAt", descending: true)
                        .limit(to: 50) ?? self!.db.collection("users").limit(to: 50)
                )
            }
            
            // Execute queries and combine results
            let group = DispatchGroup()
            var allResults: [FirebaseMember] = []
            var queryErrors: [String] = []
            
            for (index, query) in queries.enumerated() {
                group.enter()
                query.getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        let errorMsg = "Query \(index): \(error.localizedDescription)"
                        print("❌ Error in compatible members query: \(errorMsg)")
                        queryErrors.append(errorMsg)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { 
                        print("📄 Query \(index): No documents returned")
                        return 
                    }
                    
                    print("📄 Query \(index): Processing \(documents.count) documents")
                    
                    let members = documents.compactMap { document -> FirebaseMember? in
                        do {
                            if let member = try? document.data(as: FirebaseMember.self) {
                                return member
                            }
                            
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                            
                            return FirebaseMember(
                                userId: document.documentID,
                                firstName: firstName,
                                lastName: user.fullName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                gender: user.gender
                            )
                        } catch {
                            print("⚠️ Error decoding document \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ Query \(index): Successfully decoded \(members.count) members")
                    allResults.append(contentsOf: members)
                }
            }
            
            group.notify(queue: .main) {
                // Remove duplicates based on userId
                var uniqueResults: [FirebaseMember] = []
                var seenIds: Set<String> = []
                
                for member in allResults {
                    let memberId = member.userId ?? member.uniqueID
                    if !seenIds.contains(memberId) {
                        seenIds.insert(memberId)
                        uniqueResults.append(member)
                    }
                }
                
                print("🔍 COMPATIBILITY: Processed \(allResults.count) total results, \(uniqueResults.count) unique members")
                
                if uniqueResults.isEmpty {
                    print("⚠️ COMPATIBILITY: No members found via queries, falling back to cached members")
                    if !queryErrors.isEmpty {
                        print("❌ Query errors encountered: \(queryErrors.joined(separator: "; "))")
                    }
                    // Fallback to existing cached members
                    completion(self?.members ?? [])
                } else {
                    completion(uniqueResults)
                }
            }
        }
    }
    
    // MARK: - Fetch More Compatible Members with Pagination
    func fetchMoreCompatibleMembers(userGender: String?, userAttractedTo: String?, completion: @escaping ([FirebaseMember]) -> Void) {
        guard hasMoreCompatibleData else {
            print("🔍 PAGINATION: No more compatible members to fetch")
            completion([])
            return
        }
        
        guard let attractedTo = userAttractedTo?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !attractedTo.isEmpty else {
            print("🔍 PAGINATION: No attraction preference specified")
            completion([])
            return
        }
        
        print("🔍 PAGINATION: Fetching more compatible members for user attracted to '\(attractedTo)'")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var query: Query?
            
            // Build targeted query based on user preferences with unique ordering
            if attractedTo.contains("female") || attractedTo.contains("woman") || attractedTo.contains("women") || attractedTo.contains("girl") {
                let femaleVariations = ["Female", "female", "Woman", "woman", "Girl", "girl", "F", "f", "fem", "Fem"]
                query = self?.db.collection("users")
                    .whereField("gender", in: femaleVariations)
                    .whereField("firstName", isNotEqualTo: "")
                    .order(by: "createdAt", descending: true)  // Use createdAt for more stable ordering
                    .limit(to: self?.batchSize ?? 50)
            } else if attractedTo.contains("male") || attractedTo.contains("man") || attractedTo.contains("men") || attractedTo.contains("guy") {
                let maleVariations = ["Male", "male", "Man", "man", "Guy", "guy", "M", "m", "masc", "Masc"]
                query = self?.db.collection("users")
                    .whereField("gender", in: maleVariations)
                    .whereField("firstName", isNotEqualTo: "")
                    .order(by: "createdAt", descending: true)  // Use createdAt for more stable ordering
                    .limit(to: self?.batchSize ?? 50)
            } else {
                // Generic query for all genders or other preferences
                query = self?.db.collection("users")
                    .whereField("firstName", isNotEqualTo: "")
                    .order(by: "createdAt", descending: true)  // Use createdAt for more stable ordering
                    .limit(to: self?.batchSize ?? 50)
            }
            
            // Add pagination if we have a last document
            if let lastDoc = self?.lastCompatibleDocument {
                print("🔍 PAGINATION: Using cursor from lastDoc.id: \(lastDoc.documentID)")
                query = query?.start(afterDocument: lastDoc)
            } else {
                print("🔍 PAGINATION: No cursor, fetching first batch")
            }
            
            query?.getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error fetching more compatible members: \(error.localizedDescription)")
                        completion([])
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("📄 No more compatible members found")
                        self?.hasMoreCompatibleData = false
                        completion([])
                        return
                    }
                    
                    // Debug pagination state
                    print("🔍 PAGINATION: Got \(documents.count) documents")
                    print("🔍 PAGINATION: First doc ID: \(documents.first?.documentID ?? "none")")
                    print("🔍 PAGINATION: Last doc ID: \(documents.last?.documentID ?? "none")")
                    
                    // Update pagination state
                    self?.lastCompatibleDocument = documents.last
                    self?.hasMoreCompatibleData = documents.count == (self?.batchSize ?? 50)
                    
                    // Convert documents to members
                    let newMembers = documents.compactMap { document -> FirebaseMember? in
                        do {
                            if let member = try? document.data(as: FirebaseMember.self) {
                                return member
                            }
                            
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                            
                            return FirebaseMember(
                                userId: document.documentID,
                                firstName: firstName,
                                lastName: user.fullName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                gender: user.gender
                            )
                        } catch {
                            print("⚠️ Error decoding compatible member \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    
                    print("✅ PAGINATION: Fetched \(newMembers.count) new compatible members, hasMore: \(self?.hasMoreCompatibleData ?? false)")
                    completion(newMembers)
                }
            }
        }
    }
    
    // MARK: - Fetch Users Attracted To Target Gender (Fallback Function)
    func fetchUsersAttractedTo(targetGender: String, completion: @escaping ([FirebaseMember]) -> Void) {
        let normalizedGender = targetGender.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔄 FALLBACK: Fetching users attracted to '\(normalizedGender)'")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var queries: [Query] = []
            
            // Build queries based on what gender we're looking for people attracted to
            if normalizedGender.contains("female") || normalizedGender.contains("woman") || normalizedGender.contains("girl") {
                // Find users attracted to females
                let femaleAttractedVariations = ["Female", "female", "Women", "women", "Woman", "woman", "Girls", "girls", "Girl", "girl", "Females", "females"]
                
                for variation in femaleAttractedVariations {
                    queries.append(
                        self?.db.collection("users")
                            .whereField("attractedTo", isGreaterThanOrEqualTo: variation)
                            .whereField("attractedTo", isLessThan: variation + "\u{f8ff}")
                            .whereField("firstName", isNotEqualTo: "")
                            .order(by: "createdAt", descending: true)
                            .limit(to: 50) ?? self!.db.collection("users").limit(to: 50)
                    )
                }
                
                // Also search for users with "everyone" / "all" preferences
                let openPreferences = ["Everyone", "everyone", "All", "all", "Both", "both", "Anyone", "anyone"]
                for preference in openPreferences {
                    queries.append(
                        self?.db.collection("users")
                            .whereField("attractedTo", isEqualTo: preference)
                            .whereField("firstName", isNotEqualTo: "")
                            .order(by: "createdAt", descending: true)
                            .limit(to: 30) ?? self!.db.collection("users").limit(to: 30)
                    )
                }
                
            } else if normalizedGender.contains("male") || normalizedGender.contains("man") || normalizedGender.contains("guy") {
                // Find users attracted to males
                let maleAttractedVariations = ["Male", "male", "Men", "men", "Man", "man", "Guys", "guys", "Guy", "guy", "Males", "males"]
                
                for variation in maleAttractedVariations {
                    queries.append(
                        self?.db.collection("users")
                            .whereField("attractedTo", isGreaterThanOrEqualTo: variation)
                            .whereField("attractedTo", isLessThan: variation + "\u{f8ff}")
                            .whereField("firstName", isNotEqualTo: "")
                            .order(by: "createdAt", descending: true)
                            .limit(to: 50) ?? self!.db.collection("users").limit(to: 50)
                    )
                }
                
                // Also search for users with "everyone" / "all" preferences
                let openPreferences = ["Everyone", "everyone", "All", "all", "Both", "both", "Anyone", "anyone"]
                for preference in openPreferences {
                    queries.append(
                        self?.db.collection("users")
                            .whereField("attractedTo", isEqualTo: preference)
                            .whereField("firstName", isNotEqualTo: "")
                            .order(by: "createdAt", descending: true)
                            .limit(to: 30) ?? self!.db.collection("users").limit(to: 30)
                    )
                }
            } else {
                // For other genders, look for open preferences
                let openPreferences = ["Everyone", "everyone", "All", "all", "Both", "both", "Anyone", "anyone", "No preference", "no preference"]
                for preference in openPreferences {
                    queries.append(
                        self?.db.collection("users")
                            .whereField("attractedTo", isEqualTo: preference)
                            .whereField("firstName", isNotEqualTo: "")
                            .order(by: "createdAt", descending: true)
                            .limit(to: 50) ?? self!.db.collection("users").limit(to: 50)
                    )
                }
            }
            
            if queries.isEmpty {
                print("🔄 FALLBACK: No queries built for gender '\(normalizedGender)'")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Execute all queries
            let group = DispatchGroup()
            var allResults: [FirebaseMember] = []
            
            for (index, query) in queries.enumerated() {
                group.enter()
                query.getDocuments { snapshot, error in
                    defer { group.leave() }
                    
                    if let error = error {
                        print("❌ Error in fallback query \(index): \(error.localizedDescription)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    let members = documents.compactMap { document -> FirebaseMember? in
                        do {
                            if let member = try? document.data(as: FirebaseMember.self) {
                                return member
                            }
                            
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                            
                            return FirebaseMember(
                                userId: document.documentID,
                                firstName: firstName,
                                lastName: user.fullName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                gender: user.gender
                            )
                        } catch {
                            return nil
                        }
                    }
                    
                    allResults.append(contentsOf: members)
                }
            }
            
            group.notify(queue: .main) {
                // Remove duplicates
                var uniqueResults: [FirebaseMember] = []
                var seenIds: Set<String> = []
                
                for member in allResults {
                    let memberId = member.userId ?? member.uniqueID
                    if !seenIds.contains(memberId) {
                        seenIds.insert(memberId)
                        uniqueResults.append(member)
                    }
                }
                
                print("🔄 FALLBACK: Found \(uniqueResults.count) users attracted to '\(normalizedGender)'")
                completion(uniqueResults)
            }
        }
    }
    
    // MARK: - Search Members Function
    func searchMembers(query: String, completion: @escaping ([FirebaseMember]) -> Void) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            completion([])
            return
        }
        
        let searchTerm = query.lowercased()
        print("🔍 FIREBASE: Searching for '\(searchTerm)' across all members...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Search by firstName (case-insensitive)
            let firstNameQuery = self?.db.collection("users")
                .whereField("firstName", isGreaterThanOrEqualTo: searchTerm.capitalized)
                .whereField("firstName", isLessThan: searchTerm.capitalized + "\u{f8ff}")
                .limit(to: 100)
            
            firstNameQuery?.getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Search error: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion([]) }
                    return
                }
                
                var searchResults: [FirebaseMember] = []
                
                // Process firstName results
                if let documents = snapshot?.documents {
                    let firstNameResults = documents.compactMap { document -> FirebaseMember? in
                        do {
                            // Try direct decoding first
                            if let member = try? document.data(as: FirebaseMember.self) {
                                // 🔧 CRITICAL DEBUG: Direct FirebaseMember decode
                                print("🔧 DIRECT MEMBER: \(member.firstName) | Tip: '\(member.approachTip ?? "nil")'")
                                return member
                            }
                            
                            // Fallback to FirebaseUser conversion
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                            
                            return FirebaseMember(
                                userId: document.documentID,
                                firstName: firstName,
                                lastName: user.fullName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                profileImage: nil,
                                profileImageUrl: nil,
                                firebaseImageUrl: nil,
                                bio: nil,
                                location: user.city,
                                interests: nil,
                                gender: user.gender,
                                relationshipGoals: nil,
                                dateJoined: user.createdAt,
                                status: nil,
                                isActive: true,
                                lastActiveDate: user.updatedAt,
                                isVerified: false,
                                verificationDate: nil,
                                subscriptionStatus: user.subscribed == true ? "active" : "inactive",
                                fcmToken: nil,
                                profilePhoto: nil,
                                profileImageName: nil
                            )
                        } catch {
                            print("⚠️ Error decoding search result \(document.documentID): \(error)")
                            return nil
                        }
                    }
                    searchResults.append(contentsOf: firstNameResults)
                }
                
                // Now search by city
                let cityQuery = self?.db.collection("users")
                    .whereField("city", isGreaterThanOrEqualTo: searchTerm.capitalized)
                    .whereField("city", isLessThan: searchTerm.capitalized + "\u{f8ff}")
                    .limit(to: 50)
                
                cityQuery?.getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        let cityResults = documents.compactMap { document -> FirebaseMember? in
                            // Check if we already have this user from firstName search
                            if searchResults.contains(where: { $0.userId == document.documentID }) {
                                return nil
                            }
                            
                            do {
                                if let member = try? document.data(as: FirebaseMember.self) {
                                    return member
                                }
                                
                                let user = try document.data(as: FirebaseUser.self)
                                guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                                
                                return FirebaseMember(
                                    userId: document.documentID,
                                    firstName: firstName,
                                    lastName: user.fullName,
                                    age: user.age,
                                    city: user.city,
                                    attractedTo: user.attractedTo,
                                    approachTip: user.howToApproachMe,
                                    instagramHandle: user.instagramHandle,
                                    profileImage: nil,
                                    profileImageUrl: nil,
                                    firebaseImageUrl: nil,
                                    bio: nil,
                                    location: user.city,
                                    interests: nil,
                                    gender: user.gender,
                                    relationshipGoals: nil,
                                    dateJoined: user.createdAt,
                                    status: nil,
                                    isActive: true,
                                    lastActiveDate: user.updatedAt,
                                    isVerified: false,
                                    verificationDate: nil,
                                    subscriptionStatus: user.subscribed == true ? "active" : "inactive",
                                    fcmToken: nil,
                                    profilePhoto: nil,
                                    profileImageName: nil
                                )
                            } catch {
                                return nil
                            }
                        }
                        searchResults.append(contentsOf: cityResults)
                    }
                    
                    // Also perform local search on already loaded members for instant results
                    let localResults = self?.members.filter { member in
                        let name = member.firstName.lowercased()
                        let city = member.city?.lowercased() ?? ""
                        let tip = member.approachTip?.lowercased() ?? ""
                        let instagram = member.instagramHandle?.lowercased() ?? ""
                        
                        return name.contains(searchTerm) || 
                               city.contains(searchTerm) || 
                               tip.contains(searchTerm) ||
                               instagram.contains(searchTerm)
                    } ?? []
                    
                    // Combine results and remove duplicates
                    var allResults = searchResults
                    for localResult in localResults {
                        if !allResults.contains(where: { $0.userId == localResult.userId }) {
                            allResults.append(localResult)
                        }
                    }
                    
                    print("🔍 FIREBASE: Search complete - Found \(allResults.count) results for '\(searchTerm)'")
                    DispatchQueue.main.async {
                        completion(allResults)
                    }
                }
            }
        }
    }
    
    func createMember(_ member: FirebaseMember, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = member.userId else {
            completion(false, "Invalid user ID")
            return
        }
        
        do {
            try db.collection("users").document(userId).setData(from: member) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    func updateMember(_ member: FirebaseMember, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = member.userId else {
            completion(false, "Invalid user ID")
            return
        }
        
        do {
            try db.collection("users").document(userId).setData(from: member, merge: true) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func getMockMembers() -> [FirebaseMember] {
        return [
            FirebaseMember(
                userId: "1",
                firstName: "Sarah",
                age: 28,
                city: "San Francisco",
                attractedTo: "Men",
                approachTip: "Ask me about my travels!",
                instagramHandle: "@sarah_travels",
                profileImage: "https://picsum.photos/400/400?random=101"
            ),
            FirebaseMember(
                userId: "2",
                firstName: "Jake",
                age: 32,
                city: "San Francisco",
                attractedTo: "Women",
                approachTip: "Let's grab coffee and talk tech",
                instagramHandle: "@jake_codes",
                profileImage: "https://picsum.photos/400/400?random=102"
            ),
            FirebaseMember(
                userId: "3",
                firstName: "Emma",
                age: 26,
                city: "San Francisco",
                attractedTo: "Anyone",
                approachTip: "I love discussing books and art",
                instagramHandle: "@emma_reads",
                profileImage: "https://picsum.photos/400/400?random=103"
            )
        ]
    }
}

// MARK: - Firebase Events Service
class FirebaseEventsService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var events: [FirebaseEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasFetched = false
    private var cachedEvents: [FirebaseEvent] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 600 // 10 minutes cache for events
    
    func fetchEvents() {
        // Prevent redundant calls
        guard !hasFetched && !isLoading else {
            print("📋 Skipping fetchEvents - already fetched or in progress")
            return
        }
        
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !cachedEvents.isEmpty {
            print("📋 Using cached events (\(cachedEvents.count) items)")
            events = sortEventsByDatePriority(cachedEvents)
            hasFetched = true
            return
        }
        
        print("🔄 Starting fetchEvents...")
        isLoading = true
        errorMessage = nil
        
        // Fetch in background to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // UPDATED: Sort by eventDate ascending to get upcoming events first, with fallback to createdAt
            self?.db.collection("events")
                .order(by: "eventDate", descending: false)  // Future events first
                .limit(to: 50)  // Increased limit for better selection
                .getDocuments { [weak self] querySnapshot, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.hasFetched = true
                        
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            print("❌ Error fetching events: \(error.localizedDescription)")
                            
                            // Use cached data if available during error
                            if !(self?.cachedEvents.isEmpty ?? true) {
                                print("🔄 Using cached events during network error")
                                self?.events = self?.sortEventsByDatePriority(self?.cachedEvents ?? []) ?? []
                            } else {
                                // Load mock data as fallback
                                self?.events = self?.getMockEvents() ?? []
                            }
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            self?.events = []
                            return
                        }
                        
                        var eventDecodingErrors = 0
                        let events = documents.compactMap { document -> FirebaseEvent? in
                            do {
                                let event = try document.data(as: FirebaseEvent.self)
                                return event
                            } catch {
                                eventDecodingErrors += 1
                                // Only log first few errors to avoid spam
                                if eventDecodingErrors <= 3 {
                                    print("⚠️ Error decoding event \(document.documentID): \(error)")
                                }
                                return nil
                            }
                        }
                        
                        // Sort events to prioritize upcoming ones
                        let sortedEvents = self?.sortEventsByDatePriority(events) ?? events
                        
                        // Update cache
                        self?.cachedEvents = sortedEvents
                        self?.cacheTimestamp = Date()
                        self?.events = sortedEvents
                        
                        if eventDecodingErrors > 0 {
                            print("✅ Successfully loaded \(events.count) events from \(documents.count) event documents (skipped \(eventDecodingErrors) with decoding errors)")
                        } else {
                            print("✅ Successfully loaded \(events.count) events from \(documents.count) event documents")
                        }
                    }
                }
        }
    }
    
    // MARK: - Event Sorting Helper
    
    private func sortEventsByDatePriority(_ events: [FirebaseEvent]) -> [FirebaseEvent] {
        let now = Date()
        print("📅 Sorting \(events.count) events by date priority...")
        
        return events.sorted { event1, event2 in
            // Parse event dates
            let date1 = parseEventDateFromEvent(event1)
            let date2 = parseEventDateFromEvent(event2)
            
            // Handle cases where dates might be nil
            switch (date1, date2) {
            case let (d1?, d2?):
                // Both have dates - check if they're upcoming or past
                let isUpcoming1 = d1 >= now
                let isUpcoming2 = d2 >= now
                
                if isUpcoming1 && isUpcoming2 {
                    // Both upcoming - sort by date (earliest first)
                    return d1 < d2
                } else if isUpcoming1 && !isUpcoming2 {
                    // Only first is upcoming - it comes first
                    return true
                } else if !isUpcoming1 && isUpcoming2 {
                    // Only second is upcoming - it comes first
                    return false
                } else {
                    // Both are past - sort by date (most recent first)
                    return d1 > d2
                }
                
            case (nil, _?):
                // First has no date, second has date - second comes first
                return false
                
            case (_?, nil):
                // First has date, second has no date - first comes first
                return true
                
            case (nil, nil):
                // Neither has date - sort by creation date (newest first)
                let created1 = event1.createdAt?.dateValue() ?? Date.distantPast
                let created2 = event2.createdAt?.dateValue() ?? Date.distantPast
                return created1 > created2
            }
        }
    }
    
    private func parseEventDateFromEvent(_ event: FirebaseEvent) -> Date? {
        guard let eventDateString = event.eventDate else { return nil }
        return parseEventDate(eventDateString)
    }
    
    // Helper function to parse event date string to Date (copied from CheckInsView.swift)
    private func parseEventDate(_ dateString: String) -> Date? {
        let dateFormats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "yyyy-MM-dd HH:mm:ss",
            "MM/dd/yyyy HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]
        
        for format in dateFormats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        // If all else fails, try ISO8601
        if #available(iOS 10.0, *) {
            let iso8601Formatter = ISO8601DateFormatter()
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    func refreshEvents() {
        print("🔄 Force refreshing events...")
        hasFetched = false
        cachedEvents = []
        cacheTimestamp = nil
        events = []
        fetchEvents()
    }
    
    private func getMockEvents() -> [FirebaseEvent] {
        return [
            FirebaseEvent(
                eventName: "Tech Meetup",
                venueName: "WeWork",
                eventLocation: "123 Main St, San Francisco, CA",
                eventStartTime: "7:00 PM",
                eventEndTime: "9:00 PM"
            ),
            FirebaseEvent(
                eventName: "Wine Tasting",
                venueName: "The Wine Bar",
                eventLocation: "456 Market St, San Francisco, CA",
                eventStartTime: "6:00 PM",
                eventEndTime: "8:00 PM"
            )
        ]
    }
}

// MARK: - Firebase Places Service
class FirebasePlacesService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var places: [FirebasePlace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasFetched = false
    private var cachedPlaces: [FirebasePlace] = []
    private var cacheTimestamp: Date?
    private let cacheValidDuration: TimeInterval = 600 // 10 minutes cache for places
    
    func fetchPlaces() {
        // Prevent redundant calls
        guard !hasFetched && !isLoading else {
            print("📋 Skipping fetchPlaces - already fetched or in progress")
            return
        }
        
        // Check cache first
        if let cacheTimestamp = cacheTimestamp,
           Date().timeIntervalSince(cacheTimestamp) < cacheValidDuration,
           !cachedPlaces.isEmpty {
            print("📋 Using cached places (\(cachedPlaces.count) items)")
            places = cachedPlaces
            hasFetched = true
            return
        }
        
        print("🔄 Starting fetchPlaces...")
        isLoading = true
        errorMessage = nil
        
        // Fetch in background to prevent UI blocking
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.db.collection("places")
                .order(by: "createdAt", descending: true)
                .limit(to: 100)
                .getDocuments { snapshot, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            print("❌ Error fetching places: \(error)")
                            self?.errorMessage = error.localizedDescription
                            return
                        }
                        
                        guard let documents = snapshot?.documents else {
                            print("⚠️ No places found")
                            self?.places = []
                            self?.hasFetched = true
                            return
                        }
                        
                        do {
                            let fetchedPlaces = try documents.compactMap { document -> FirebasePlace? in
                                let place = try document.data(as: FirebasePlace.self)
                                // Log if document ID is missing for debugging
                                if place.id == nil || place.id?.isEmpty == true {
                                    print("🔧 DEBUG: Place '\(place.placeName ?? "Unknown")' missing document ID (will use computed uniqueID)")
                                }
                                return place
                            }
                            
                            print("✅ Fetched \(fetchedPlaces.count) places from Firebase")
                            
                            // Cache the results
                            self?.cachedPlaces = fetchedPlaces
                            self?.cacheTimestamp = Date()
                            self?.places = fetchedPlaces
                            self?.hasFetched = true
                            
                        } catch {
                            print("❌ Error decoding places: \(error)")
                            self?.errorMessage = "Failed to load places data"
                        }
                    }
                }
        }
    }
    
    func refreshPlaces() {
        print("🔄 Forcing places refresh...")
        hasFetched = false
        cacheTimestamp = nil
        cachedPlaces = []
        fetchPlaces()
    }
}

// MARK: - Firebase Check-ins Service
class FirebaseCheckInsService: ObservableObject {
    private let db = Firestore.firestore()
    private let locationManager = LocationManager.shared
    
    @Published var checkIns: [FirebaseCheckIn] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Location-based Check-in Methods
    
    func checkInWithLocationValidation(userId: String, eventId: String, event: FirebaseEvent, completion: @escaping (Bool, String?) -> Void) {
        print("🔥 LOCATION CHECKIN: Starting location-validated check-in process...")
        
        // Step 1: Check if user has location permission
        guard locationManager.hasLocationPermission else {
            print("❌ LOCATION CHECKIN: No location permission")
            completion(false, "Location permission required. Please enable location access in Settings.")
            return
        }
        
        // Step 2: Get current location if needed
        guard locationManager.location != nil else {
            print("📍 LOCATION CHECKIN: Getting current location...")
            locationManager.requestOneTimeLocation()
            
            // Wait a moment for location update, then retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.checkInWithLocationValidation(userId: userId, eventId: eventId, event: event, completion: completion)
            }
            return
        }
        
        // Step 3: Validate event has coordinates
        guard let eventCoordinates = event.coordinates else {
            print("❌ LOCATION CHECKIN: Event has no coordinates")
            // For events without coordinates, fall back to regular check-in
            checkIn(userId: userId, eventId: eventId, completion: completion)
            return
        }
        
        // Step 4: Check distance to event
        let isInRange = locationManager.isWithinCheckInRange(of: eventCoordinates)
        guard isInRange else {
            let distance = locationManager.formattedDistance(to: eventCoordinates)
            print("❌ LOCATION CHECKIN: User too far from event (\(distance))")
            completion(false, "You must be within 1 mile of the event to check in. You are currently \(distance) away.")
            return
        }
        
        // Step 5: Proceed with normal check-in
        print("✅ LOCATION CHECKIN: Location validated, proceeding with check-in")
        checkIn(userId: userId, eventId: eventId, completion: completion)
    }
    
    func checkIn(userId: String, eventId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔥 FIREBASE CHECKIN: Starting check-in process for user \(userId) to \(eventId)")
        
        // Check if user is already checked in
        isUserCheckedIn(userId: userId, eventId: eventId) { [weak self] isAlreadyCheckedIn in
            if isAlreadyCheckedIn {
                print("⚠️ FIREBASE CHECKIN: User already checked in")
                completion(false, "You are already checked in")
                return
            }
            
                    // Try to add user to places collection first
        self?.addUserToCollection(userId: userId, itemId: eventId, collection: "places") { success in
            if success {
                print("✅ FIREBASE CHECKIN: SUCCESS - Added user to place")
                completion(true, nil)
            } else {
                // If not a place, try events collection
                self?.addUserToCollection(userId: userId, itemId: eventId, collection: "events") { success in
                    if success {
                        print("✅ FIREBASE CHECKIN: SUCCESS - Added user to event")
                        completion(true, nil)
                    } else {
                        print("❌ FIREBASE CHECKIN: Failed to add user to either places or events")
                        print("❌ FIREBASE CHECKIN: Searched for ID: \(eventId) in both collections")
                        
                        // Try to provide helpful debugging info
                        self?.debugSearchForSimilarItems(searchId: eventId) { foundItems in
                            let debugMessage = foundItems.isEmpty ? 
                                "No similar items found in database" : 
                                "Found similar items: \(foundItems.prefix(3).joined(separator: ", "))"
                            print("🔍 FIREBASE CHECKIN: \(debugMessage)")
                            completion(false, "Item not found. \(debugMessage)")
                        }
                    }
                }
            }
        }
        }
    }
    
    private func addUserToCollection(userId: String, itemId: String, collection: String, completion: @escaping (Bool) -> Void) {
        print("🔍 FIREBASE CHECKIN: Checking \(collection) collection for document: \(itemId)")
        
        // ENHANCED: If itemId looks like a computed uniqueID, try to find the real document first
        if itemId.contains("_") && !itemId.contains("-") {
            print("🔧 FIREBASE CHECKIN: Detected computed ID '\(itemId)', searching for real document...")
            findEventByComputedId(itemId: itemId, collection: collection) { [weak self] realDocumentId in
                if let realId = realDocumentId {
                    print("✅ FIREBASE CHECKIN: Found real document ID: \(realId)")
                    self?.addUserToCollection(userId: userId, itemId: realId, collection: collection, completion: completion)
                } else {
                    // Fallback to original logic
                    self?.directDocumentLookup(userId: userId, itemId: itemId, collection: collection, completion: completion)
                }
            }
            return
        }
        
        // Normal direct lookup for proper UUIDs
        directDocumentLookup(userId: userId, itemId: itemId, collection: collection, completion: completion)
    }
    
    private func directDocumentLookup(userId: String, itemId: String, collection: String, completion: @escaping (Bool) -> Void) {
        db.collection(collection).document(itemId).getDocument { document, error in
            if let error = error {
                print("❌ FIREBASE CHECKIN: Error getting document from \(collection): \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let doc = document, doc.exists else {
                print("📭 FIREBASE CHECKIN: Document \(itemId) not found in \(collection) collection")
                completion(false)
                return
            }
            
            print("✅ FIREBASE CHECKIN: Found document \(itemId) in \(collection) collection")
            var data = doc.data() ?? [:]
            var users = data["Users"] as? [Any] ?? []
            let userIdStrings = users.compactMap { "\($0)" }
            
            // Add user if not already present
            if !userIdStrings.contains(userId) {
                users.append(userId)
                data["Users"] = users
                
                print("🔄 FIREBASE CHECKIN: Adding user \(userId) to \(collection) document \(itemId)")
                self.db.collection(collection).document(itemId).updateData(data) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            print("❌ FIREBASE CHECKIN: Failed to update \(collection) document: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            print("✅ FIREBASE CHECKIN: Successfully added user to \(collection)")
                            completion(true)
                        }
                    }
                }
            } else {
                print("ℹ️ FIREBASE CHECKIN: User \(userId) already in \(collection) document \(itemId)")
                DispatchQueue.main.async {
                    completion(true) // Already present
                }
            }
        }
    }
    
    func checkOut(userId: String, eventId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔥 FIREBASE CHECKOUT: Starting check-out process for user \(userId) from \(eventId)")
        
        // Try to remove user from places collection first
        removeUserFromCollection(userId: userId, itemId: eventId, collection: "places") { [weak self] success in
            if success {
                print("✅ FIREBASE CHECKOUT: SUCCESS - Removed user from place")
                completion(true, nil)
            } else {
                // If not a place, try events collection
                self?.removeUserFromCollection(userId: userId, itemId: eventId, collection: "events") { success in
                    if success {
                        print("✅ FIREBASE CHECKOUT: SUCCESS - Removed user from event")
                        completion(true, nil)
                    } else {
                        print("❌ FIREBASE CHECKOUT: User not found in either places or events")
                        completion(false, "Not checked in")
                    }
                }
            }
        }
    }
    
    private func removeUserFromCollection(userId: String, itemId: String, collection: String, completion: @escaping (Bool) -> Void) {
        db.collection(collection).document(itemId).getDocument { document, error in
            guard let doc = document, doc.exists else {
                completion(false)
                return
            }
            
            var data = doc.data() ?? [:]
            var users = data["Users"] as? [Any] ?? []
            let userIdStrings = users.compactMap { "\($0)" }
            
            // Remove user if present
            if let index = userIdStrings.firstIndex(of: userId) {
                users.remove(at: index)
                data["Users"] = users
                
                self.db.collection(collection).document(itemId).updateData(data) { error in
                    DispatchQueue.main.async {
                        completion(error == nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false) // User not found
                }
            }
        }
    }
    
    func isUserCheckedIn(userId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        print("🔍 FIREBASE CHECKIN: Checking if user \(userId) is checked in to \(eventId)")
        
        // First check places collection
        db.collection("places").document(eventId).getDocument { document, error in
            if let doc = document, doc.exists, let data = doc.data(),
               let users = data["Users"] as? [Any] {
                let userIdStrings = users.compactMap { "\($0)" }
                let isCheckedIn = userIdStrings.contains(userId)
                print("🔍 FIREBASE CHECKIN: User check-in status in place: \(isCheckedIn)")
                DispatchQueue.main.async {
                    completion(isCheckedIn)
                }
                return
            }
            
            // If not found in places, check events collection
            self.db.collection("events").document(eventId).getDocument { document, error in
                if let doc = document, doc.exists, let data = doc.data(),
                   let users = data["Users"] as? [Any] {
                    let userIdStrings = users.compactMap { "\($0)" }
                    let isCheckedIn = userIdStrings.contains(userId)
                    print("🔍 FIREBASE CHECKIN: User check-in status in event: \(isCheckedIn)")
                    DispatchQueue.main.async {
                        completion(isCheckedIn)
                    }
                } else {
                    print("🔍 FIREBASE CHECKIN: User not checked in (item not found)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
    }
    
    func getCheckInCount(for itemId: String, completion: @escaping (Int) -> Void) {
        print("📊 FIREBASE CHECKIN: Getting check-in count for item: \(itemId)")
        
        // First try to get count from places collection (which has Users array)
        db.collection("places").document(itemId).getDocument { document, error in
            if let doc = document, doc.exists, let data = doc.data(),
               let users = data["Users"] as? [Any] {
                let count = users.count
                print("📊 FIREBASE CHECKIN: Place \(itemId) has \(count) check-ins from Users array")
                DispatchQueue.main.async {
                    completion(count)
                }
                return
            }
            
            // If not found in places, try events collection
            self.db.collection("events").document(itemId).getDocument { document, error in
                if let doc = document, doc.exists, let data = doc.data(),
                   let users = data["Users"] as? [Any] {
                    let count = users.count
                    print("📊 FIREBASE CHECKIN: Event \(itemId) has \(count) check-ins from Users array")
                    DispatchQueue.main.async {
                        completion(count)
                    }
                } else {
                    print("📊 FIREBASE CHECKIN: No check-ins found for \(itemId)")
                    DispatchQueue.main.async {
                        completion(0)
                    }
                }
            }
        }
    }
    
    // Get check-in count from actual Firebase data structure
    func getHistoricalCheckInCount(for itemId: String, itemType: String = "event", completion: @escaping (Int) -> Void) {
        print("📊 FIREBASE CHECKIN: Getting check-in count from \(itemType) document: \(itemId)")
        
        // Use the same logic as getCheckInCount since historical = current in our data structure
        getCheckInCount(for: itemId, completion: completion)
    }
    
    // ENHANCED: Get combined check-in count (real-time + historical)
    func getCombinedCheckInCount(for itemId: String, itemType: String = "event", completion: @escaping (Int, Int) -> Void) {
        print("📊 FIREBASE CHECKIN: Getting combined check-in count for \(itemType): \(itemId)")
        
        var currentCount = 0
        var historicalCount = 0
        let dispatchGroup = DispatchGroup()
        
        // Get current active check-ins
        dispatchGroup.enter()
        getCheckInCount(for: itemId) { count in
            currentCount = count
            dispatchGroup.leave()
        }
        
        // Get historical check-ins from user documents
        dispatchGroup.enter()
        getHistoricalCheckInCount(for: itemId, itemType: itemType) { count in
            historicalCount = count
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            print("📊 FIREBASE CHECKIN: Combined counts - Current: \(currentCount), Historical: \(historicalCount)")
            completion(currentCount, historicalCount)
        }
    }
    
    // ENHANCED: Check if user has ever been to this place/event (using history + current)
    func hasUserEverCheckedIn(userId: String, itemId: String, itemType: String = "event", completion: @escaping (Bool, Bool) -> Void) {
        print("🔍 FIREBASE CHECKIN: Checking if user has ever checked in to \(itemType): \(itemId)")
        
        var isCurrentlyCheckedIn = false
        var hasHistoricalCheckIn = false
        let dispatchGroup = DispatchGroup()
        
        // Check if currently checked in (real-time collection)
        dispatchGroup.enter()
        isUserCheckedIn(userId: userId, eventId: itemId) { checkedIn in
            isCurrentlyCheckedIn = checkedIn
            dispatchGroup.leave()
        }
        
        // Check user's historical check-in data
        dispatchGroup.enter()
        db.collection("users").document(userId).getDocument { document, error in
            if let doc = document, doc.exists, let userData = doc.data() {
                if let checkInHistory = userData["checkInHistory"] as? [String: Any] {
                    let events = checkInHistory["events"] as? [String] ?? []
                    let places = checkInHistory["places"] as? [String] ?? []
                    
                    if itemType == "event" {
                        hasHistoricalCheckIn = events.contains(itemId)
                    } else {
                        hasHistoricalCheckIn = places.contains(itemId)
                    }
                }
            }
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            print("🔍 FIREBASE CHECKIN: User status - Currently: \(isCurrentlyCheckedIn), Historically: \(hasHistoricalCheckIn)")
            completion(isCurrentlyCheckedIn, hasHistoricalCheckIn)
        }
    }
    
    func getMembersAtEvent(_ eventId: String, completion: @escaping ([FirebaseMember]) -> Void) {
        print("👥 FIREBASE CHECKIN: Getting members who checked in to event: \(eventId)")
        
        // Get the event document and extract Users array
        db.collection("events").document(eventId).getDocument { document, error in
            if let error = error {
                print("❌ FIREBASE CHECKIN: Error getting event: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            guard let doc = document, doc.exists, let data = doc.data(),
                  let userIds = data["Users"] as? [Any] else {
                print("📊 FIREBASE CHECKIN: No users found for event \(eventId)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            // Convert to string array
            let userIdStrings = userIds.compactMap { "\($0)" }
            print("📊 FIREBASE CHECKIN: Found \(userIdStrings.count) users for event")
            
            // Fetch user profiles for these user IDs
            self.fetchMembersById(userIds: userIdStrings, completion: completion)
        }
    }
    
    func getMembersAtPlace(_ placeId: String, completion: @escaping ([FirebaseMember]) -> Void) {
        print("👥 FIREBASE CHECKIN: Getting members who checked in to place: \(placeId)")
        
        // Get the place document and extract Users array
        db.collection("places").document(placeId).getDocument { document, error in
            if let error = error {
                print("❌ FIREBASE CHECKIN: Error getting place: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            guard let doc = document, doc.exists, let data = doc.data(),
                  let userIds = data["Users"] as? [Any] else {
                print("📊 FIREBASE CHECKIN: No users found for place \(placeId)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            // Convert to string array
            let userIdStrings = userIds.compactMap { "\($0)" }
            print("📊 FIREBASE CHECKIN: Found \(userIdStrings.count) users for place")
            
            // Fetch user profiles for these user IDs
            self.fetchMembersById(userIds: userIdStrings, completion: completion)
        }
    }
    
    private func fetchMembersById(userIds: [String], completion: @escaping ([FirebaseMember]) -> Void) {
        print("👥 FIREBASE CHECKIN: Fetching \(userIds.count) user profiles: \(userIds)")
        var members: [FirebaseMember] = []
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            print("👤 FIREBASE CHECKIN: Fetching user: \(userId)")
            
            db.collection("users").document(userId).getDocument { document, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ FIREBASE CHECKIN: Error fetching user \(userId): \(error.localizedDescription)")
                    return
                }
                
                guard let document = document, document.exists else {
                    print("❌ FIREBASE CHECKIN: User document \(userId) not found")
                    return
                }
                
                let data = document.data() ?? [:]
                print("👤 FIREBASE CHECKIN: User \(userId) data keys: \(data.keys.joined(separator: ", "))")
                
                // Get the first name - this is required
                guard let firstName = data["firstName"] as? String, !firstName.isEmpty else {
                    print("❌ FIREBASE CHECKIN: User \(userId) missing firstName")
                    return
                }
                
                // Try to decode as FirebaseMember directly first (proper way)
                do {
                    let member = try document.data(as: FirebaseMember.self)
                    members.append(member)
                    print("✅ FIREBASE CHECKIN: Successfully decoded FirebaseMember: \(firstName) (ID: \(document.documentID))")
                } catch {
                    // Fallback: Manual creation if direct decoding fails
                    print("⚠️ FIREBASE CHECKIN: Direct decoding failed for \(userId), creating manually: \(error.localizedDescription)")
                    
                    let member = FirebaseMember(
                        userId: document.documentID,
                        firstName: firstName,
                        lastName: data["lastName"] as? String,
                        age: data["age"] as? Int,
                        city: data["city"] as? String,
                        attractedTo: data["attractedTo"] as? String,
                        approachTip: data["howToApproachMe"] as? String, // Map from Firestore field
                        instagramHandle: data["instagramHandle"] as? String,
                        profileImage: nil, // Legacy field - not used
                        profileImageUrl: nil, // Legacy field - not used 
                        firebaseImageUrl: nil, // Legacy field - not used
                        bio: data["bio"] as? String,
                        location: data["city"] as? String,
                        interests: data["interests"] as? [String],
                        gender: data["gender"] as? String,
                        relationshipGoals: data["relationshipGoals"] as? String,
                        dateJoined: data["createdAt"] as? Timestamp,
                        status: data["status"] as? String,
                        isActive: true,
                        lastActiveDate: data["updatedAt"] as? Timestamp,
                        isVerified: data["isVerified"] as? Bool ?? false,
                        verificationDate: data["verificationDate"] as? Timestamp,
                        subscriptionStatus: data["subscribed"] as? Bool == true ? "active" : "inactive",
                        fcmToken: data["fcmToken"] as? String,
                        profilePhoto: data["profilePhoto"] as? String,
                        profileImageName: data["profileImageName"] as? String
                    )
                    
                    members.append(member)
                    print("✅ FIREBASE CHECKIN: Successfully created FirebaseMember manually: \(firstName) (ID: \(document.documentID))")
                }
            }
        }
        
        group.notify(queue: .main) {
            print("👥 FIREBASE CHECKIN: Successfully loaded \(members.count) out of \(userIds.count) members")
            for member in members {
                print("   - \(member.firstName) (ID: \(member.id ?? "unknown"))")
            }
            completion(members)
        }
    }
    
    // Helper function to search for similar items when exact match fails
    // NEW: Find real document ID by computed uniqueID with flexible fuzzy matching
    private func findEventByComputedId(itemId: String, collection: String, completion: @escaping (String?) -> Void) {
        // Parse the computed ID to extract event/place name
        let components = itemId.components(separatedBy: "_")
        guard components.count >= 2 else {
            completion(nil)
            return
        }
        
        let searchName = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let venueName = components.count > 2 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
        print("🔍 FIREBASE CHECKIN: Flexible search in \(collection) for name '\(searchName)' or venue '\(venueName)'")
        
        // Perform broader search to get more documents for fuzzy matching
        db.collection(collection)
            .limit(to: 50) // Get more documents for better matching
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ FIREBASE CHECKIN: Error searching \(collection): \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("📭 FIREBASE CHECKIN: No documents found in \(collection) search")
                    completion(nil)
                    return
                }
                
                print("🔍 FIREBASE CHECKIN: Got \(documents.count) documents to search through")
                
                // Fuzzy matching with scoring
                var bestMatch: (documentId: String, score: Double)? = nil
                
                for document in documents {
                    let data = document.data()
                    var score = 0.0
                    
                    if collection == "events" {
                        let eventName = (data["eventName"] as? String ?? "").lowercased()
                        let venue = (data["venueName"] as? String ?? "").lowercased()
                        
                        // Score based on how well the search name matches
                        score += self.calculateMatchScore(searchName.lowercased(), eventName)
                        score += self.calculateMatchScore(searchName.lowercased(), venue)
                        
                        // Bonus for venue name match if provided
                        if !venueName.isEmpty {
                            score += self.calculateMatchScore(venueName.lowercased(), venue) * 1.5
                            score += self.calculateMatchScore(venueName.lowercased(), eventName) * 1.2
                        }
                        
                        print("🔍 FIREBASE CHECKIN: Event '\(eventName)' at '\(venue)' - Score: \(score)")
                        
                    } else {
                        let placeName = (data["placeName"] as? String ?? "").lowercased()
                        
                        score += self.calculateMatchScore(searchName.lowercased(), placeName)
                        
                        print("🔍 FIREBASE CHECKIN: Place '\(placeName)' - Score: \(score)")
                    }
                    
                    // Update best match if this is better
                    if score > 0.5 && (bestMatch == nil || score > bestMatch!.score) {
                        bestMatch = (document.documentID, score)
                    }
                }
                
                if let match = bestMatch {
                    print("✅ FIREBASE CHECKIN: Best match found: \(match.documentId) with score \(match.score)")
                    completion(match.documentId)
                } else {
                    print("❌ FIREBASE CHECKIN: No good matches found for '\(searchName)'")
                    completion(nil)
                }
            }
    }
    
    // Calculate fuzzy match score between two strings
    private func calculateMatchScore(_ search: String, _ target: String) -> Double {
        guard !search.isEmpty && !target.isEmpty else { return 0.0 }
        
        let searchWords = search.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let targetWords = target.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var totalScore = 0.0
        var maxPossibleScore = 0.0
        
        for searchWord in searchWords {
            maxPossibleScore += 1.0
            var bestWordScore = 0.0
            
            for targetWord in targetWords {
                let wordScore = calculateWordMatchScore(searchWord, targetWord)
                bestWordScore = max(bestWordScore, wordScore)
            }
            
            totalScore += bestWordScore
        }
        
        return maxPossibleScore > 0 ? totalScore / maxPossibleScore : 0.0
    }
    
    // Calculate similarity between two words
    private func calculateWordMatchScore(_ word1: String, _ word2: String) -> Double {
        // Exact match
        if word1 == word2 {
            return 1.0
        }
        
        // Contains match
        if word2.contains(word1) || word1.contains(word2) {
            return 0.8
        }
        
        // Starts with match
        if word2.hasPrefix(word1) || word1.hasPrefix(word2) {
            return 0.7
        }
        
        // Levenshtein distance-based similarity
        let distance = levenshteinDistance(word1, word2)
        let maxLength = max(word1.count, word2.count)
        let similarity = 1.0 - Double(distance) / Double(maxLength)
        
        // Only consider it a match if similarity is high enough
        return similarity > 0.6 ? similarity * 0.6 : 0.0
    }
    
    // Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a1 = Array(s1)
        let a2 = Array(s2)
        let m = a1.count
        let n = a2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if a1[i-1] == a2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
    
    private func debugSearchForSimilarItems(searchId: String, completion: @escaping ([String]) -> Void) {
        print("🔍 FIREBASE CHECKIN: Searching for similar items to: \(searchId)")
        var foundItems: [String] = []
        let group = DispatchGroup()
        
        // Search events for name matches or ID patterns
        group.enter()
        db.collection("events").limit(to: 10).getDocuments { snapshot, error in
            defer { group.leave() }
            if let docs = snapshot?.documents {
                for doc in docs {
                    let data = doc.data()
                    let eventName = data["eventName"] as? String ?? data["name"] as? String ?? ""
                    let venueName = data["venueName"] as? String ?? ""
                    
                    // Check if searchId contains parts of the event/venue name
                    let searchLower = searchId.lowercased()
                    let eventLower = eventName.lowercased()
                    let venueLower = venueName.lowercased()
                    
                    if (!eventName.isEmpty && (searchLower.contains(eventLower) || eventLower.contains(searchLower))) ||
                       (!venueName.isEmpty && (searchLower.contains(venueLower) || venueLower.contains(searchLower))) {
                        foundItems.append("event:\(doc.documentID)(\(eventName.isEmpty ? venueName : eventName))")
                        print("🔍 Found similar event: \(doc.documentID) (\(eventName.isEmpty ? venueName : eventName))")
                    }
                }
            }
        }
        
        // Search places for name matches
        group.enter()
        db.collection("places").limit(to: 10).getDocuments { snapshot, error in
            defer { group.leave() }
            if let docs = snapshot?.documents {
                for doc in docs {
                    let data = doc.data()
                    let placeName = data["placeName"] as? String ?? data["name"] as? String ?? ""
                    
                    // Check if searchId contains parts of the place name
                    let searchLower = searchId.lowercased()
                    let placeLower = placeName.lowercased()
                    
                    if !placeName.isEmpty && (searchLower.contains(placeLower) || placeLower.contains(searchLower)) {
                        foundItems.append("place:\(doc.documentID)(\(placeName))")
                        print("🔍 Found similar place: \(doc.documentID) (\(placeName))")
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(foundItems)
        }
    }
    
    func fetchCheckIns() {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Fetch in background with smaller batch size
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.db.collection("checkIns")
                .whereField("isActive", isEqualTo: true)
                .limit(to: 20)  // Reduced from 50 to prevent blocking
                .getDocuments { [weak self] querySnapshot, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            print("❌ Error fetching check-ins: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            self?.checkIns = []
                            return
                        }
                        
                        let checkIns = documents.compactMap { document -> FirebaseCheckIn? in
                            do {
                                return try document.data(as: FirebaseCheckIn.self)
                            } catch {
                                print("⚠️ Error decoding check-in: \(error)")
                                return nil
                            }
                        }
                        
                        self?.checkIns = checkIns
                        print("✅ Successfully loaded \(checkIns.count) check-ins")
                    }
                }
        }
    }
}

// MARK: - Firebase Conversations Service
class FirebaseConversationsService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var conversations: [FirebaseConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchConversations(for userId: String) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Fetch in background with smaller batch size
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.db.collection("conversations")
                .whereField("participantIds", arrayContains: userId)
                .limit(to: 20)  // Reduced from 50 to prevent blocking
                .getDocuments { [weak self] querySnapshot, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            print("❌ Error fetching conversations: \(error.localizedDescription)")
                            self?.conversations = self?.getMockConversations(for: userId) ?? []
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            self?.conversations = []
                            return
                        }
                        
                        let conversations = documents.compactMap { document -> FirebaseConversation? in
                            do {
                                return try document.data(as: FirebaseConversation.self)
                            } catch {
                                print("⚠️ Error decoding conversation: \(error)")
                                return nil
                            }
                        }
                        
                        self?.conversations = conversations
                        print("✅ Successfully loaded \(conversations.count) conversations")
                    }
                }
        }
    }
    
    func createConversation(participantOneId: String, participantTwoId: String, completion: @escaping (Bool, String?) -> Void) {
        let conversation = FirebaseConversation(
            participantOneId: participantOneId,
            participantTwoId: participantTwoId
        )
        
        do {
            try db.collection("conversations").addDocument(from: conversation) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func getMockConversations(for userId: String) -> [FirebaseConversation] {
        return [
            FirebaseConversation(
                participantOneId: userId,
                participantTwoId: "2",
                lastMessage: "Hey! How was the event last night?"
            ),
            FirebaseConversation(
                participantOneId: userId,
                participantTwoId: "3",
                lastMessage: "Thanks for the book recommendation!"
            ),
            FirebaseConversation(
                participantOneId: "4",
                participantTwoId: userId,
                lastMessage: "Let's grab coffee sometime this week?"
            )
        ]
    }
}

// MARK: - Firebase Messages Service
class FirebaseMessagesService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var messages: [FirebaseMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchMessages(for conversationId: String) {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Fetch in background with smaller batch size
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "createdAt", descending: false)
                .limit(to: 50)  // Reduced from 100 to prevent blocking
                .getDocuments { [weak self] querySnapshot, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            self?.errorMessage = error.localizedDescription
                            print("❌ Error fetching messages: \(error.localizedDescription)")
                            // Load mock data as fallback
                            self?.messages = self?.getMockMessages(for: conversationId) ?? []
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            self?.messages = []
                            return
                        }
                        
                        let messages = documents.compactMap { document -> FirebaseMessage? in
                            do {
                                return try document.data(as: FirebaseMessage.self)
                            } catch {
                                print("⚠️ Error decoding message: \(error)")
                                return nil
                            }
                        }
                        
                        self?.messages = messages
                        print("✅ Successfully loaded \(messages.count) messages")
                    }
                }
        }
    }
    
    func sendMessage(conversationId: String, senderId: String, messageText: String, completion: @escaping (Bool, String?) -> Void) {
        let message = FirebaseMessage(
            conversationId: conversationId,
            senderId: senderId,
            messageText: messageText
        )
        
        do {
            try db.collection("messages").addDocument(from: message) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        // Update the conversation's last message
                        self.updateConversationLastMessage(conversationId: conversationId, lastMessage: messageText)
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func updateConversationLastMessage(conversationId: String, lastMessage: String) {
        db.collection("conversations").document(conversationId).updateData([
            "lastMessage": lastMessage,
            "lastMessageAt": Timestamp(),
            "updatedAt": Timestamp()
        ])
    }
    
    private func getMockMessages(for conversationId: String) -> [FirebaseMessage] {
        return [
            FirebaseMessage(
                conversationId: conversationId,
                senderId: "2",
                messageText: "Hey! How was the event last night?"
            ),
            FirebaseMessage(
                conversationId: conversationId,
                senderId: "123",
                messageText: "It was amazing! The live music was incredible 🎵"
            )
        ]
    }
}

// MARK: - Firebase Storage Service
class FirebaseStorageService {
    private let storage = Storage.storage()
    
    func uploadImage(_ imageData: Data, path: String, completion: @escaping (String?, Error?) -> Void) {
        let storageRef = storage.reference().child(path)
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(nil, error)
                } else if let url = url {
                    completion(url.absoluteString, nil)
                } else {
                    completion(nil, NSError(domain: "StorageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"]))
                }
            }
        }
    }
}

// MARK: - Main Firebase Services Class (SCALABLE!)
class FirebaseServices {
    static let shared = FirebaseServices()
    
    private init() {
        print("🔧 FirebaseServices singleton initialized")
    }
    
    // MARK: - UUID-BASED IMAGE UPLOAD SYSTEM
    func uploadProfileImage(_ image: UIImage, for userId: String, adaloId: Int?) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "ImageError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        // Use UUID-based filename (cleaner system)
        let filename = "\(userId).jpg"
        
        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("profiles/\(filename)")
        
        print("📸 Uploading UUID-based image: \(filename)")
        
        // Upload the image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.customMetadata = [
            "userId": userId,
            "uploadedAt": String(Int(Date().timeIntervalSince1970))
        ]
        
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        
        // Get the public URL (Firebase Storage API format)
        let publicUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/profiles%2F\(filename)?alt=media"
        
        // Update Firestore with the image URL
        let db = Firestore.firestore()
        try await db.collection("users").document(userId).updateData([
            "hasProfileImage": true,
            "profileImageUpdatedAt": FieldValue.serverTimestamp()
        ])
        
        print("✅ UUID-based image uploaded: \(publicUrl)")
        return publicUrl
    }
    
    // MARK: - USER CREATION WITH PROPER IMAGE RELATIONSHIP
    func createUserWithProperImageLink(
        email: String,
        password: String,
        firstName: String,
        lastName: String,
        adaloId: Int? = nil,
        profileImage: UIImage? = nil
    ) async throws -> String {
        
        // Create Firebase Auth user
        let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
        let userId = authResult.user.uid
        
        var userData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "email": email,
            "createdAt": FieldValue.serverTimestamp(),
            "userId": userId
        ]
        
        // Add adaloId if provided (for legacy compatibility)
        if let adaloId = adaloId {
            userData["adaloId"] = adaloId
        }
        
        // Upload image if provided and get URL
        if let image = profileImage {
            let imageUrl = try await uploadProfileImage(image, for: userId, adaloId: adaloId)
            userData["profileImageUrl"] = imageUrl
            userData["firebaseImageUrl"] = imageUrl
        }
        
        // Create Firestore document with all data including image URL
        let db = Firestore.firestore()
        try await db.collection("users").document(userId).setData(userData)
        
        print("✅ User created with proper image relationship: \(firstName)")
        return userId
    }
    
    // Legacy sync removed - using UUID-based system now
}

