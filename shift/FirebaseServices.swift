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
        print("🔐 FirebaseUserSession init: Thread=MAIN")
        
        // Listen for auth state changes
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            print("🔐 Auth state changed: user=\(user?.uid ?? "nil")")
            print("🔐 Auth state change: Thread=BACKGROUND")
            
            DispatchQueue.main.async {
                print("🔐 Processing auth state change on main thread")
                if let user = user {
                    print("🔐 Firebase auth state: User signed in (\(user.uid))")
                    self?.loadUserDataIfNeeded(uid: user.uid)
                } else {
                    print("🔐 Firebase auth state: User signed out")
                    self?.currentUser = nil
                    self?.isLoggedIn = false
                    self?.isLoadingUserData = false
                }
            }
        }
        
        // Check current auth state immediately
        print("🔐 Checking current auth state immediately")
        checkCurrentAuthState()
    }
    
    private func checkCurrentAuthState() {
        print("🔐 checkCurrentAuthState: Thread=MAIN")
        
        if let currentUser = auth.currentUser {
            print("🔐 Found existing authenticated user: \(currentUser.uid)")
            loadUserDataIfNeeded(uid: currentUser.uid)
        } else {
            print("🔐 No existing authenticated user found")
            isLoggedIn = false
        }
    }
    
    deinit {
        print("🔐 FirebaseUserSession deinit")
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }
    
    func signUp(email: String, password: String, firstName: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔐 Starting signUp: Thread=MAIN")
        isLoading = true
        errorMessage = nil
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            print("🔐 SignUp auth response: Thread=BACKGROUND")
            
            DispatchQueue.main.async {
                print("🔐 Processing signUp response on main thread")
                self?.isLoading = false
                
                if let error = error {
                    print("🔐 SignUp error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                guard let uid = result?.user.uid else {
                    print("🔐 SignUp error: Failed to get user ID")
                    completion(false, "Failed to get user ID")
                    return
                }
                
                print("🔐 SignUp success, creating user document for UID: \(uid)")
                
                // Create user document in Firestore
                let newUser = FirebaseUser(
                    email: email,
                    firstName: firstName
                )
                
                self?.createUserDocument(user: newUser, uid: uid) { success, error in
                    print("🔐 User document creation result: success=\(success), error=\(error ?? "none")")
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
        print("🔐 Starting password reset: Thread=MAIN")
        
        auth.sendPasswordReset(withEmail: email) { error in
            print("🔐 Password reset response: Thread=BACKGROUND")
            
            DispatchQueue.main.async {
                print("🔐 Processing password reset response on main thread")
                if let error = error {
                    print("🔐 Password reset error: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    print("🔐 Password reset success")
                    completion(true, nil)
                }
            }
        }
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
            // Get ALL users for dating app - we need the full pool
            self?.db.collection("users")
                .whereField("firstName", isNotEqualTo: "")  // Only users with names
                .limit(to: 500)  // Much larger batch for dating app
                .getDocuments { [weak self] querySnapshot, error in
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
                        
                        // Process documents efficiently  
                        let members = documents.compactMap { document -> FirebaseMember? in
                            do {
                                // First try to decode as FirebaseMember directly from the document
                                // This will properly map all Firebase fields including profileImageUrl
                                if let member = try? document.data(as: FirebaseMember.self) {
                                    return member
                                }
                                
                                // Fallback: decode as FirebaseUser and convert
                                let user = try document.data(as: FirebaseUser.self)
                                guard let firstName = user.firstName, !firstName.isEmpty else { 
                                    return nil // This should be rare now due to the query filter
                                }
                                
                                // Check for ALL possible image fields directly from document data
                                let data = document.data()
                                // Legacy URL fields exist but are ignored in pure UUID system
                                let _ = data["profileImageUrl"] as? String
                                let _ = data["firebaseImageUrl"] as? String  
                                let _ = data["profilePhoto"] as? String
                                let profilePicture = data["profilePicture"] as? String
                                let legacyImageUrl = data["imageUrl"] as? String
                                let photoUrl = data["photoUrl"] as? String
                                
                                print("🔍 === COMPLETE DOCUMENT DATA FOR \(firstName) ===")
                                print("🔍 Document ID: \(document.documentID)")
                                print("🔍 All available fields: \(data.keys.sorted().joined(separator: ", "))")
                                print("🔍 Legacy URLs detected but IGNORED (using UUID-only system)")
                                print("🔍 profilePicture: \(profilePicture ?? "nil")")
                                print("🔍 legacyImageUrl: \(legacyImageUrl ?? "nil")")
                                print("🔍 photoUrl: \(photoUrl ?? "nil")")
                                print("🔍 user.profilePhoto: \(user.profilePhoto ?? "nil")")
                                
                                // Check for ID-related fields
                                if let adaloId = data["adaloId"] {
                                    print("🔍 adaloId: \(adaloId) (type: \(type(of: adaloId)))")
                                } else {
                                    print("🔍 ❌ adaloId: NOT FOUND")
                                }
                                
                                if let id = data["id"] {
                                    print("🔍 id: \(id) (type: \(type(of: id)))")
                                } else {
                                    print("🔍 ❌ id: NOT FOUND")
                                }
                                
                                if let originalId = data["originalId"] {
                                    print("🔍 originalId: \(originalId) (type: \(type(of: originalId)))")
                                } else {
                                    print("🔍 ❌ originalId: NOT FOUND")
                                }
                                
                                print("🔍 ===================================================")
                                
                                // UNIVERSAL SYSTEM: Same image URL construction for ALL users (migrated + future)
                                let imageUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/profiles%2F\(document.documentID).jpg?alt=media"
                                print("🔧 Using universal image URL for \(firstName): \(imageUrl)")
                                
                                let member = FirebaseMember(
                                    userId: document.documentID, // Use document ID (UUID v4) instead of Firebase Auth UID
                                    firstName: firstName,
                                    lastName: user.fullName, // Use fullName as lastName fallback
                                    age: user.age,
                                    city: user.city,
                                    attractedTo: user.attractedTo,
                                    approachTip: user.howToApproachMe,
                                    instagramHandle: user.instagramHandle,
                                    profileImage: nil, // No legacy URLs
                                    profileImageUrl: nil, // No legacy URLs
                                    firebaseImageUrl: nil, // No legacy URLs
                                    bio: nil, // Not available in FirebaseUser
                                    location: user.city, // Use city as location
                                    interests: nil, // Not available in FirebaseUser
                                    gender: user.gender,
                                    relationshipGoals: nil, // Not available in FirebaseUser
                                    dateJoined: user.createdAt,
                                    status: nil, // Not available in FirebaseUser
                                    isActive: true, // Default to active
                                    lastActiveDate: user.updatedAt,
                                    isVerified: false, // Default to unverified
                                    verificationDate: nil, // Not available in FirebaseUser
                                    subscriptionStatus: user.subscribed == true ? "active" : "inactive",
                                    fcmToken: nil, // Not available in FirebaseUser
                                    profilePhoto: nil, // No legacy URLs
                                    profileImageName: nil // No legacy URLs
                                )
                                
                                print("🔧 ✅ FINAL MEMBER CREATED FOR \(firstName):")
                                print("🔧    computed profileImageURL: \(member.profileImageURL?.absoluteString ?? "nil")")
                                
                                return member
                            } catch {
                                // Log error but continue processing
                                print("⚠️ Error decoding user \(document.documentID): \(error.localizedDescription)")
                                return nil
                            }
                        }
                        
                        // Update cache
                        self?.cachedMembers = members
                        self?.cacheTimestamp = Date()
                        self?.members = members
                        
                        print("✅ Successfully loaded \(members.count) members from \(documents.count) user documents")
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
                                return try document.data(as: FirebaseEvent.self)
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
        print("🔥 FIREBASE CHECKIN: Starting check-in process...")
        print("🔥 FIREBASE CHECKIN: userId=\(userId), eventId=\(eventId)")
        
        // Check if user is already checked in to this event
        isUserCheckedIn(userId: userId, eventId: eventId) { [weak self] isAlreadyCheckedIn in
            if isAlreadyCheckedIn {
                print("⚠️ FIREBASE CHECKIN: User already checked in to this event")
                completion(false, "You are already checked in to this event")
                return
            }
            
            // Create check-in document
            let checkIn = FirebaseCheckIn(
                userId: userId,
                eventId: eventId
            )
            
            print("🔥 FIREBASE CHECKIN: Created check-in object: \(checkIn)")
            
            do {
                print("🔥 FIREBASE CHECKIN: Attempting to add document to Firestore...")
                try self?.db.collection("checkIns").addDocument(from: checkIn) { error in
                    print("🔥 FIREBASE CHECKIN: Firestore addDocument callback received")
                    DispatchQueue.main.async {
                        print("🔥 FIREBASE CHECKIN: Processing on main thread")
                        if let error = error {
                            print("❌ FIREBASE CHECKIN: Failed with error: \(error.localizedDescription)")
                            completion(false, error.localizedDescription)
                        } else {
                            print("✅ FIREBASE CHECKIN: SUCCESS - User \(userId) checked in to event \(eventId)")
                            completion(true, nil)
                        }
                    }
                }
            } catch {
                print("❌ FIREBASE CHECKIN: Exception during addDocument: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            }
        }
    }
    
    func checkOut(userId: String, eventId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔥 FIREBASE CHECKOUT: Starting check-out process...")
        
        // Find the active check-in for this user and event
        db.collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { querySnapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ FIREBASE CHECKOUT: Error finding check-in: \(error.localizedDescription)")
                        completion(false, error.localizedDescription)
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents, let checkInDoc = documents.first else {
                        print("❌ FIREBASE CHECKOUT: No active check-in found")
                        completion(false, "No active check-in found")
                        return
                    }
                    
                    // Update the check-in to mark it as inactive
                    checkInDoc.reference.updateData([
                        "isActive": false,
                        "checkedOutAt": Timestamp()
                    ]) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("❌ FIREBASE CHECKOUT: Failed with error: \(error.localizedDescription)")
                                completion(false, error.localizedDescription)
                            } else {
                                print("✅ FIREBASE CHECKOUT: SUCCESS - User \(userId) checked out of event \(eventId)")
                                completion(true, nil)
                            }
                        }
                    }
                }
            }
    }
    
    func isUserCheckedIn(userId: String, eventId: String, completion: @escaping (Bool) -> Void) {
        print("🔍 FIREBASE CHECKIN: Checking if user is already checked in...")
        print("🔍 FIREBASE CHECKIN: userId=\(userId), eventId=\(eventId)")
        
        db.collection("checkIns")
            .whereField("userId", isEqualTo: userId)
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { querySnapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ FIREBASE CHECKIN: Error checking status: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    let isCheckedIn = !(querySnapshot?.documents.isEmpty ?? true)
                    print("🔍 FIREBASE CHECKIN: User check-in status: \(isCheckedIn)")
                    completion(isCheckedIn)
                }
            }
    }
    
    func getCheckInCount(for eventId: String, completion: @escaping (Int) -> Void) {
        print("📊 FIREBASE CHECKIN: Getting check-in count for event: \(eventId)")
        
        db.collection("checkIns")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { querySnapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ FIREBASE CHECKIN: Error getting count: \(error.localizedDescription)")
                        completion(0)
                        return
                    }
                    
                    let count = querySnapshot?.documents.count ?? 0
                    print("📊 FIREBASE CHECKIN: Event \(eventId) has \(count) check-ins")
                    completion(count)
                }
            }
    }
    
    func getMembersAtEvent(_ eventId: String, completion: @escaping ([FirebaseMember]) -> Void) {
        print("👥 FIREBASE CHECKIN: Getting members checked in to event: \(eventId)")
        
        // Get all active check-ins for this event
        db.collection("checkIns")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("isActive", isEqualTo: true)
            .getDocuments { [weak self] querySnapshot, error in
                if let error = error {
                    print("❌ FIREBASE CHECKIN: Error getting check-ins: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("📊 FIREBASE CHECKIN: No check-ins found for event")
                    completion([])
                    return
                }
                
                let userIds = documents.compactMap { document -> String? in
                    return document.data()["userId"] as? String
                }
                
                guard !userIds.isEmpty else {
                    print("📊 FIREBASE CHECKIN: No user IDs found in check-ins")
                    completion([])
                    return
                }
                
                // Batch fetch user profiles for all checked-in users
                self?.fetchMembersById(userIds: userIds, completion: completion)
            }
    }
    
    private func fetchMembersById(userIds: [String], completion: @escaping ([FirebaseMember]) -> Void) {
        var members: [FirebaseMember] = []
        let group = DispatchGroup()
        
        for userId in userIds {
            group.enter()
            db.collection("users").document(userId).getDocument { document, error in
                if let document = document, document.exists {
                    let data = document.data() ?? [:]
                    let member = FirebaseMember(
                        id: document.documentID,
                        firstName: data["firstName"] as? String ?? "Unknown",
                        lastName: data["lastName"] as? String ?? "",
                        age: data["age"] as? Int,
                        city: data["city"] as? String,
                        approachTip: data["approachTip"] as? String,
                        profileImage: data["profileImage"] as? String,
                        profileImageUrl: data["profileImageUrl"] as? String,
                        bio: data["bio"] as? String,
                        interests: data["interests"] as? [String]
                    )
                    members.append(member)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("👥 FIREBASE CHECKIN: Successfully loaded \(members.count) members")
            completion(members)
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
