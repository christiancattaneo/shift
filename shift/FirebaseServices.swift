import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
    
    private init() {
        // Listen for auth state changes
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.loadUserData(uid: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isLoggedIn = false
                }
            }
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
        isLoading = true
        errorMessage = nil
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                completion(true, nil)
            }
        }
    }
    
    func signOut() {
        do {
            try auth.signOut()
            currentUser = nil
            isLoggedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func createUserDocument(user: FirebaseUser, uid: String, completion: @escaping (Bool, String?) -> Void) {
        
        do {
            try db.collection("users").document(uid).setData(from: user) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        self.currentUser = user
                        self.isLoggedIn = true
                        completion(true, nil)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    private func loadUserData(uid: String) {
        db.collection("users").document(uid).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let document = document, document.exists else {
                    self?.errorMessage = "User document not found"
                    return
                }
                
                do {
                    let user = try document.data(as: FirebaseUser.self)
                    self?.currentUser = user
                    self?.isLoggedIn = true
                } catch {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateUserProfile(_ user: FirebaseUser, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = user.id else {
            completion(false, "Invalid user ID")
            return
        }
        
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        self.currentUser = user
                        completion(true, nil)
                    }
                }
            }
        } catch {
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
    
    func loadSavedUser() {
        // Firebase Auth automatically handles persistence
        // The auth state listener will be triggered on app launch
    }
}

// MARK: - Firebase Members Service
class FirebaseMembersService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var members: [FirebaseMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var hasFetched = false  // Prevent redundant calls
    
    func fetchMembers() {
        // Prevent redundant calls that were causing freezing
        guard !hasFetched && !isLoading else {
            print("📋 Skipping fetchMembers - already fetched or in progress")
            return
        }
        
        isLoading = true
        hasFetched = true
        errorMessage = nil
        
        // Use one-time fetch instead of real-time listener to prevent blocking
        // Add pagination to avoid loading 1336 documents at once
        db.collection("users")
            .limit(to: 200)  // Limit to first 200 users to prevent freezing
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        print("❌ Error fetching members: \(error.localizedDescription)")
                        // Load mock data as fallback
                        self?.members = self?.getMockMembers() ?? []
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        self?.members = []
                        return
                    }
                    
                    var skippedUsersCount = 0
                    let members = documents.compactMap { document -> FirebaseMember? in
                        do {
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { 
                                skippedUsersCount += 1
                                return nil 
                            }
                            
                            return FirebaseMember(
                                userId: user.id,
                                firstName: firstName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                profileImage: user.profilePhoto  // This will be constructed into Firebase Storage URL by the decoder
                            )
                        } catch {
                            print("⚠️ Error decoding user \(document.documentID): \(error.localizedDescription)")
                            // Continue processing other users instead of failing completely
                            return nil
                        }
                    }
                    
                    self?.members = members
                    if skippedUsersCount > 0 {
                        print("✅ Successfully loaded \(members.count) members from \(documents.count) user documents (skipped \(skippedUsersCount) users without firstName)")
                    } else {
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
    
    private var hasFetched = false  // Prevent redundant calls
    
    func fetchEvents() {
        // Prevent redundant calls
        guard !hasFetched && !isLoading else {
            print("📋 Skipping fetchEvents - already fetched or in progress")
            return
        }
        
        isLoading = true
        hasFetched = true
        errorMessage = nil
        
        // Use one-time fetch for initial load to prevent freezing
        db.collection("events")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)  // Limit events to prevent blocking
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        // Load mock data as fallback
                        self?.events = self?.getMockEvents() ?? []
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
                    
                    self?.events = events
                    if eventDecodingErrors > 0 {
                        print("✅ Successfully loaded \(events.count) events from \(documents.count) event documents (skipped \(eventDecodingErrors) with decoding errors)")
                    } else {
                        print("✅ Successfully loaded \(events.count) events from \(documents.count) event documents")
                    }
                }
            }
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
    
    @Published var checkIns: [FirebaseCheckIn] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchCheckIns() {
        isLoading = true
        errorMessage = nil
        
        // Use one-time fetch to prevent blocking
        db.collection("checkIns")
            .whereField("isActive", isEqualTo: true)
            .limit(to: 50)  // Limit check-ins
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
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
                            print("Error decoding check-in: \(error)")
                            return nil
                        }
                    }
                    
                    self?.checkIns = checkIns
                }
            }
    }
    
    func checkIn(userId: String, eventId: String, completion: @escaping (Bool, String?) -> Void) {
        let checkIn = FirebaseCheckIn(userId: userId, eventId: eventId)
        
        do {
            try db.collection("checkIns").addDocument(from: checkIn) { error in
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
    
    func getMembersAtEvent(_ eventId: String) -> [FirebaseMember] {
        // This would need to be implemented with proper queries
        return []
    }
}

// MARK: - Firebase Conversations Service
class FirebaseConversationsService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var conversations: [FirebaseConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchConversations(for userId: String) {
        isLoading = true
        errorMessage = nil
        
        // Use single optimized query instead of two separate listeners
        db.collection("conversations")
            .whereField("participantIds", arrayContains: userId)  // Assumes participantIds array field
            .limit(to: 50)  // Limit conversations to prevent blocking
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
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
                            print("Error decoding conversation: \(error)")
                            return nil
                        }
                    }
                    
                    self?.conversations = conversations
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
        isLoading = true
        errorMessage = nil
        
        // Use one-time fetch for initial load to prevent blocking
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .limit(to: 100)  // Limit messages to most recent 100
            .getDocuments { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
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
                            print("Error decoding message: \(error)")
                            return nil
                        }
                    }
                    
                    self?.messages = messages
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