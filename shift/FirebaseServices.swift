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
                    id: uid,
                    email: email,
                    firstName: firstName
                )
                
                self?.createUserDocument(user: newUser) { success, error in
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
    
    private func createUserDocument(user: FirebaseUser, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = user.id else {
            completion(false, "Invalid user ID")
            return
        }
        
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
    
    func fetchMembers() {
        isLoading = true
        errorMessage = nil
        
        db.collection("users")
            .addSnapshotListener { [weak self] querySnapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        // Load mock data as fallback
                        self?.members = self?.getMockMembers() ?? []
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        self?.members = []
                        return
                    }
                    
                    let members = documents.compactMap { document -> FirebaseMember? in
                        do {
                            let user = try document.data(as: FirebaseUser.self)
                            guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                            
                            return FirebaseMember(
                                id: user.id,
                                firstName: firstName,
                                age: user.age,
                                city: user.city,
                                attractedTo: user.attractedTo,
                                approachTip: user.howToApproachMe,
                                instagramHandle: user.instagramHandle,
                                profileImage: user.profilePhoto
                            )
                        } catch {
                            print("Error decoding user: \(error)")
                            return nil
                        }
                    }
                    
                    self?.members = members
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
                id: "1",
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
                id: "2",
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
                id: "3",
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
    
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        
        db.collection("events")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
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
                    
                    let events = documents.compactMap { document -> FirebaseEvent? in
                        do {
                            return try document.data(as: FirebaseEvent.self)
                        } catch {
                            print("Error decoding event: \(error)")
                            return nil
                        }
                    }
                    
                    self?.events = events
                }
            }
    }
    
    private func getMockEvents() -> [FirebaseEvent] {
        return [
            FirebaseEvent(
                id: "1",
                eventName: "Tech Meetup",
                venueName: "WeWork",
                eventLocation: "123 Main St, San Francisco, CA",
                eventStartTime: "7:00 PM",
                eventEndTime: "9:00 PM"
            ),
            FirebaseEvent(
                id: "2",
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
        
        db.collection("checkIns")
            .whereField("isActive", isEqualTo: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
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
        
        db.collection("conversations")
            .whereField("participantOneId", isEqualTo: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleConversationSnapshot(querySnapshot: querySnapshot, error: error, userId: userId)
            }
        
        db.collection("conversations")
            .whereField("participantTwoId", isEqualTo: userId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                self?.handleConversationSnapshot(querySnapshot: querySnapshot, error: error, userId: userId)
            }
    }
    
    private func handleConversationSnapshot(querySnapshot: QuerySnapshot?, error: Error?, userId: String) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                // Load mock data as fallback
                self.conversations = self.getMockConversations(for: userId)
                return
            }
            
            guard let documents = querySnapshot?.documents else { return }
            
            let newConversations = documents.compactMap { document -> FirebaseConversation? in
                do {
                    return try document.data(as: FirebaseConversation.self)
                } catch {
                    print("Error decoding conversation: \(error)")
                    return nil
                }
            }
            
            // Merge with existing conversations
            var allConversations = self.conversations
            for newConversation in newConversations {
                if !allConversations.contains(where: { $0.id == newConversation.id }) {
                    allConversations.append(newConversation)
                }
            }
            
            self.conversations = allConversations
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
                id: "1",
                participantOneId: userId,
                participantTwoId: "2",
                lastMessage: "Hey! How was the event last night?"
            ),
            FirebaseConversation(
                id: "2",
                participantOneId: userId,
                participantTwoId: "3",
                lastMessage: "Thanks for the book recommendation!"
            ),
            FirebaseConversation(
                id: "3",
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
        
        db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
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
                id: "1",
                conversationId: conversationId,
                senderId: "2",
                messageText: "Hey! How was the event last night?"
            ),
            FirebaseMessage(
                id: "2",
                conversationId: conversationId,
                senderId: "123",
                messageText: "It was amazing! The live music was incredible 🎵"
            )
        ]
    }
}

// MARK: - Firebase Storage Service
class FirebaseStorageService: ObservableObject {
    private let storage = Storage.storage()
    
    @Published var uploadProgress: Double = 0.0
    @Published var isUploading = false
    @Published var errorMessage: String?
    
    func uploadImage(_ imageData: Data, path: String, completion: @escaping (String?, String?) -> Void) {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        let storageRef = storage.reference().child(path)
        
        let uploadTask = storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            DispatchQueue.main.async {
                self?.isUploading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(nil, error.localizedDescription)
                    return
                }
                
                storageRef.downloadURL { url, error in
                    if let error = error {
                        completion(nil, error.localizedDescription)
                    } else {
                        completion(url?.absoluteString, nil)
                    }
                }
            }
        }
        
        uploadTask.observe(.progress) { [weak self] snapshot in
            guard let progress = snapshot.progress else { return }
            DispatchQueue.main.async {
                self?.uploadProgress = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
            }
        }
    }
    
    func deleteImage(path: String, completion: @escaping (Bool, String?) -> Void) {
        let storageRef = storage.reference().child(path)
        
        storageRef.delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
} 