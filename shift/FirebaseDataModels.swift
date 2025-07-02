import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - Helper Types for Dynamic Decoding
struct AnyDecodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyDecodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.init(())
        } else if let bool = try? container.decode(Bool.self) {
            self.init(bool)
        } else if let int = try? container.decode(Int.self) {
            self.init(int)
        } else if let double = try? container.decode(Double.self) {
            self.init(double)
        } else if let string = try? container.decode(String.self) {
            self.init(string)
        } else if let array = try? container.decode([AnyDecodable].self) {
            self.init(array.map { $0.value })
        } else if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.init(dictionary.mapValues { $0.value })
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyDecodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyDecodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyDecodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyDecodable value cannot be encoded")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

// MARK: - User Models
struct FirebaseUser: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let email: String?  // Made optional to handle legacy data without email
    let username: String?
    let fullName: String?
    let firstName: String?
    let profilePhoto: String?
    let gender: String?
    let attractedTo: String?
    let age: Int?
    let city: String?
    let howToApproachMe: String?
    let isEventCreator: Bool?
    let isEventAttendee: Bool?
    let instagramHandle: String?
    let subscribed: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    let adaloId: Int?
    let originalAdaloId: Int?
    
    // NEW: Check-in history from user document
    let checkInHistory: UserCheckInHistory?
    
    // Custom initializer for handling Firebase data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // IMPORTANT: Let @DocumentID handle itself - don't try to decode it manually
        // The @DocumentID property wrapper will be handled automatically by Firestore
        
        // Handle profilePhoto - could be String or Dictionary
        if let photoString = try? container.decode(String.self, forKey: .profilePhoto) {
            self.profilePhoto = photoString
        } else {
            // Try to decode as a dictionary and extract URL
            if let photoDict = try? container.decodeIfPresent([String: AnyDecodable].self, forKey: .profilePhoto),
               let urlValue = photoDict["url"]?.value as? String {
                // If it's just a filename, construct the Firebase Storage URL
                if !urlValue.hasPrefix("http") {
                    self.profilePhoto = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/profiles%2F\(urlValue)?alt=media"
                    print("🔗 Constructed Firebase Storage API URL from user filename: \(urlValue)")
                } else {
                    self.profilePhoto = urlValue
                    print("🔗 Using direct URL from user photo dict: \(urlValue)")
                }
            } else {
                self.profilePhoto = nil
            }
        }
        
        // Standard fields
        self.email = try? container.decode(String.self, forKey: .email)
        self.username = try? container.decode(String.self, forKey: .username)
        self.fullName = try? container.decode(String.self, forKey: .fullName)
        self.firstName = try? container.decode(String.self, forKey: .firstName)
        self.gender = try? container.decode(String.self, forKey: .gender)
        self.attractedTo = try? container.decode(String.self, forKey: .attractedTo)
        self.age = try? container.decode(Int.self, forKey: .age)
        self.city = try? container.decode(String.self, forKey: .city)
        self.howToApproachMe = try? container.decode(String.self, forKey: .howToApproachMe)
        self.isEventCreator = try? container.decode(Bool.self, forKey: .isEventCreator)
        self.isEventAttendee = try? container.decode(Bool.self, forKey: .isEventAttendee)
        self.instagramHandle = try? container.decode(String.self, forKey: .instagramHandle)
        self.subscribed = try? container.decode(Bool.self, forKey: .subscribed)
        self.createdAt = try? container.decode(Timestamp.self, forKey: .createdAt)
        self.updatedAt = try? container.decode(Timestamp.self, forKey: .updatedAt)
        self.adaloId = try? container.decode(Int.self, forKey: .adaloId)
        self.originalAdaloId = try? container.decode(Int.self, forKey: .originalAdaloId)
        self.checkInHistory = try? container.decode(UserCheckInHistory.self, forKey: .checkInHistory)
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(fullName, forKey: .fullName)
        try container.encodeIfPresent(firstName, forKey: .firstName)
        try container.encodeIfPresent(profilePhoto, forKey: .profilePhoto)
        try container.encodeIfPresent(gender, forKey: .gender)
        try container.encodeIfPresent(attractedTo, forKey: .attractedTo)
        try container.encodeIfPresent(age, forKey: .age)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(howToApproachMe, forKey: .howToApproachMe)
        try container.encodeIfPresent(isEventCreator, forKey: .isEventCreator)
        try container.encodeIfPresent(isEventAttendee, forKey: .isEventAttendee)
        try container.encodeIfPresent(instagramHandle, forKey: .instagramHandle)
        try container.encodeIfPresent(subscribed, forKey: .subscribed)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(adaloId, forKey: .adaloId)
        try container.encodeIfPresent(originalAdaloId, forKey: .originalAdaloId)
        try container.encodeIfPresent(checkInHistory, forKey: .checkInHistory)
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, email, username, fullName, firstName, profilePhoto, gender, attractedTo, age, city
        case howToApproachMe, isEventCreator, isEventAttendee, instagramHandle, subscribed, createdAt, updatedAt
        case adaloId, originalAdaloId, checkInHistory
    }
    
    // Manual initializer for local creation (not from Firestore)
    init(email: String?, firstName: String?, fullName: String? = nil, profilePhoto: String? = nil, username: String? = nil, gender: String? = nil, attractedTo: String? = nil, age: Int? = nil, city: String? = nil, howToApproachMe: String? = nil, isEventCreator: Bool? = nil, instagramHandle: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.email = email
        self.username = username
        self.fullName = fullName
        self.firstName = firstName
        self.profilePhoto = profilePhoto
        self.gender = gender
        self.attractedTo = attractedTo
        self.age = age
        self.city = city
        self.howToApproachMe = howToApproachMe
        self.isEventCreator = isEventCreator
        self.isEventAttendee = nil
        self.instagramHandle = instagramHandle
        self.subscribed = nil
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
        self.adaloId = nil
        self.originalAdaloId = nil
        self.checkInHistory = nil
    }
    
    // Helper computed property for email display
    var displayEmail: String {
        return email ?? "No email provided"
    }
}

// MARK: - Member Profile Models
struct FirebaseMember: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let userId: String?
    let firstName: String
    let lastName: String?
    let age: Int?
    let city: String?
    let attractedTo: String?
    let approachTip: String?
    let instagramHandle: String?
    let profileImage: String?        // Legacy Adalo field (likely dead URLs)
    let profileImageUrl: String?     // NEW Firebase Storage field (working URLs)
    let firebaseImageUrl: String?    // Alternative Firebase field name
    let bio: String?
    let location: String?
    let interests: [String]?
    let gender: String?
    let relationshipGoals: String?
    let dateJoined: Timestamp?
    let status: String?
    let isActive: Bool?
    let lastActiveDate: Timestamp?
    let isVerified: Bool?
    let verificationDate: Timestamp?
    let subscriptionStatus: String?
    let fcmToken: String?
    let profilePhoto: String?
    let profileImageName: String?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Computed property to ensure unique ID for SwiftUI ForEach
    var uniqueID: String {
        // Use Firebase document ID first (most stable)
        if let id = id, !id.isEmpty {
            return id
        }
        
        // Use userId if available
        if let userId = userId, !userId.isEmpty {
            return userId
        }
        
        // Create a stable fallback ID without using hashValue
        // This ensures the same member always gets the same ID
        let nameHash = abs(firstName.lowercased().hashValue) % 10000
        let cityHash = abs((city?.lowercased() ?? "").hashValue) % 1000
        let timeHash = abs(Int(createdAt?.seconds ?? 0)) % 10000
        
        return "member_\(nameHash)_\(age ?? 0)_\(cityHash)_\(timeHash)"
    }
    
    // Convenience initializer
    init(
        id: String? = nil,
        userId: String? = nil, 
        firstName: String, 
        lastName: String? = nil,
        age: Int? = nil, 
        city: String? = nil, 
        attractedTo: String? = nil, 
        approachTip: String? = nil, 
        instagramHandle: String? = nil, 
        profileImage: String? = nil, 
        profileImageUrl: String? = nil, 
        firebaseImageUrl: String? = nil,
        bio: String? = nil,
        location: String? = nil,
        interests: [String]? = nil,
        gender: String? = nil,
        relationshipGoals: String? = nil,
        dateJoined: Timestamp? = nil,
        status: String? = nil,
        isActive: Bool? = nil,
        lastActiveDate: Timestamp? = nil,
        isVerified: Bool? = nil,
        verificationDate: Timestamp? = nil,
        subscriptionStatus: String? = nil,
        fcmToken: String? = nil,
        profilePhoto: String? = nil,
        profileImageName: String? = nil
    ) {
        // Don't set self.id in init - @DocumentID is managed by Firestore
        self.userId = userId
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.city = city
        self.attractedTo = attractedTo
        self.approachTip = approachTip
        self.instagramHandle = instagramHandle
        self.profileImage = profileImage
        self.profileImageUrl = profileImageUrl
        self.firebaseImageUrl = firebaseImageUrl
        self.bio = bio
        self.location = location
        self.interests = interests
        self.gender = gender
        self.relationshipGoals = relationshipGoals
        self.dateJoined = dateJoined
        self.status = status
        self.isActive = isActive ?? true
        self.lastActiveDate = lastActiveDate
        self.isVerified = isVerified
        self.verificationDate = verificationDate
        self.subscriptionStatus = subscriptionStatus
        self.fcmToken = fcmToken
        self.profilePhoto = profilePhoto
        self.profileImageName = profileImageName
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
}

// MARK: - Event Models
struct FirebaseEvent: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let eventName: String?
    let venueName: String?
    let eventLocation: String?
    let eventStartTime: String?
    let eventEndTime: String?
    let image: String?               // Legacy Adalo field (likely dead URLs)
    let imageUrl: String?            // NEW Firebase Storage field (working URLs)
    let firebaseImageUrl: String?    // Alternative Firebase field name
    let isEventFree: Bool?
    let eventCategory: String?
    let eventDate: String?
    let place: String?
    // NEW: Location data for distance-based check-ins
    let coordinates: EventCoordinates?
    let city: String?
    let state: String?
    let country: String?
    let address: String?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    // NEW: Popularity tracking fields
    let popularityScore: Double?
    let recentCheckIns: Int?
    let weeklyCheckIns: Int?
    let totalCheckIns: Int?
    let popularityUpdatedAt: Timestamp?
    
    // Computed property to ensure unique ID for SwiftUI ForEach
    var uniqueID: String {
        // Use Firebase document ID first (most stable)
        if let id = id, !id.isEmpty {
            return id
        }
        
        // Create a consistent fallback ID based on event data
        if let eventName = eventName, !eventName.isEmpty {
            return "\(eventName.lowercased())_\(venueName?.lowercased() ?? "")_\(createdAt?.seconds ?? 0)"
        }
        
        if let venueName = venueName, !venueName.isEmpty {
            return "\(venueName.lowercased())_\(createdAt?.seconds ?? 0)"
        }
        
        // Last resort: use timestamp
        return "event_\(createdAt?.seconds ?? 0)"
    }
    
    // Custom initializer for handling Firebase data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // IMPORTANT: Let @DocumentID handle itself - don't try to decode it manually
        // The @DocumentID property wrapper will be handled automatically by Firestore
        
        // Handle eventStartTime - could be String or Timestamp
        if let timestampValue = try? container.decode(Timestamp.self, forKey: .eventStartTime) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            self.eventStartTime = formatter.string(from: timestampValue.dateValue())
        } else {
            self.eventStartTime = try? container.decode(String.self, forKey: .eventStartTime)
        }
        
        // Handle eventEndTime - could be String or Timestamp
        if let timestampValue = try? container.decode(Timestamp.self, forKey: .eventEndTime) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            self.eventEndTime = formatter.string(from: timestampValue.dateValue())
        } else {
            self.eventEndTime = try? container.decode(String.self, forKey: .eventEndTime)
        }
        
        // Handle Firebase Storage URLs (NEW - these work!)
        self.imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        self.firebaseImageUrl = try? container.decode(String.self, forKey: .firebaseImageUrl)
        
        // Handle legacy image field - could be String or Dictionary
        if let imageString = try? container.decode(String.self, forKey: .image) {
            self.image = imageString
        } else {
            // Try to decode as a dictionary and extract URL
            if let imageDict = try? container.decodeIfPresent([String: AnyDecodable].self, forKey: .image),
               let urlValue = imageDict["url"]?.value as? String {
                // If it's just a filename, construct the Firebase Storage URL using events/ directory
                if !urlValue.hasPrefix("http") {
                    self.image = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/events%2F\(urlValue)?alt=media"
                    print("🔗 Using clean event image: \(urlValue)")
                } else {
                    self.image = urlValue
                    print("🔗 Using direct URL from image dict: \(urlValue)")
                }
            } else {
                self.image = nil
            }
        }
        
        // NEW: Handle coordinates
        self.coordinates = try? container.decode(EventCoordinates.self, forKey: .coordinates)
        
        // Standard fields
        self.eventName = try? container.decode(String.self, forKey: .eventName)
        self.venueName = try? container.decode(String.self, forKey: .venueName)
        self.eventLocation = try? container.decode(String.self, forKey: .eventLocation)
        self.isEventFree = try? container.decode(Bool.self, forKey: .isEventFree)
        self.eventCategory = try? container.decode(String.self, forKey: .eventCategory)
        self.eventDate = try? container.decode(String.self, forKey: .eventDate)
        self.place = try? container.decode(String.self, forKey: .place)
        // NEW: Location fields
        self.city = try? container.decode(String.self, forKey: .city)
        self.state = try? container.decode(String.self, forKey: .state)
        self.country = try? container.decode(String.self, forKey: .country)
        self.address = try? container.decode(String.self, forKey: .address)
        self.createdAt = try? container.decode(Timestamp.self, forKey: .createdAt)
        self.updatedAt = try? container.decode(Timestamp.self, forKey: .updatedAt)
        // NEW: Popularity fields
        self.popularityScore = try? container.decode(Double.self, forKey: .popularityScore)
        self.recentCheckIns = try? container.decode(Int.self, forKey: .recentCheckIns)
        self.weeklyCheckIns = try? container.decode(Int.self, forKey: .weeklyCheckIns)
        self.totalCheckIns = try? container.decode(Int.self, forKey: .totalCheckIns)
        self.popularityUpdatedAt = try? container.decode(Timestamp.self, forKey: .popularityUpdatedAt)
        
        // DEBUG: Add logging to see what's happening with ID
        print("🔍 Event decoded: \(eventName ?? "Unknown") - Document ID will be set by @DocumentID")
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(eventName, forKey: .eventName)
        try container.encodeIfPresent(venueName, forKey: .venueName)
        try container.encodeIfPresent(eventLocation, forKey: .eventLocation)
        try container.encodeIfPresent(eventStartTime, forKey: .eventStartTime)
        try container.encodeIfPresent(eventEndTime, forKey: .eventEndTime)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encodeIfPresent(firebaseImageUrl, forKey: .firebaseImageUrl)
        try container.encodeIfPresent(isEventFree, forKey: .isEventFree)
        try container.encodeIfPresent(eventCategory, forKey: .eventCategory)
        try container.encodeIfPresent(eventDate, forKey: .eventDate)
        try container.encodeIfPresent(place, forKey: .place)
        // NEW: Location fields
        try container.encodeIfPresent(coordinates, forKey: .coordinates)
        try container.encodeIfPresent(city, forKey: .city)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(country, forKey: .country)
        try container.encodeIfPresent(address, forKey: .address)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        // NEW: Popularity fields
        try container.encodeIfPresent(popularityScore, forKey: .popularityScore)
        try container.encodeIfPresent(recentCheckIns, forKey: .recentCheckIns)
        try container.encodeIfPresent(weeklyCheckIns, forKey: .weeklyCheckIns)
        try container.encodeIfPresent(totalCheckIns, forKey: .totalCheckIns)
        try container.encodeIfPresent(popularityUpdatedAt, forKey: .popularityUpdatedAt)
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case eventName, venueName, eventLocation, eventStartTime, eventEndTime
        case image, imageUrl, firebaseImageUrl, isEventFree, eventCategory, eventDate, place
        case coordinates, city, state, country, address, createdAt, updatedAt
        case popularityScore, recentCheckIns, weeklyCheckIns, totalCheckIns, popularityUpdatedAt
    }
    
    // Manual initializer for local creation (not from Firestore)
    init(eventName: String, venueName: String? = nil, eventLocation: String? = nil, eventStartTime: String? = nil, eventEndTime: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.eventName = eventName
        self.venueName = venueName
        self.eventLocation = eventLocation
        self.eventStartTime = eventStartTime
        self.eventEndTime = eventEndTime
        self.image = nil
        self.imageUrl = nil          // Initialize new Firebase Storage fields
        self.firebaseImageUrl = nil
        self.isEventFree = nil
        self.eventCategory = nil
        self.eventDate = nil
        self.place = nil
        // NEW: Initialize location fields
        self.coordinates = nil
        self.city = nil
        self.state = nil
        self.country = nil
        self.address = nil
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
        // NEW: Initialize popularity fields
        self.popularityScore = nil
        self.recentCheckIns = nil
        self.weeklyCheckIns = nil
        self.totalCheckIns = nil
        self.popularityUpdatedAt = nil
    }
}

// MARK: - Location Support Types
struct EventCoordinates: Codable, Hashable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Place Models
struct FirebasePlace: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let placeName: String?
    let placeLocation: String?
    let placeImage: String?          // Legacy field
    let imageUrl: String?            // NEW Firebase Storage field (working URLs)
    let firebaseImageUrl: String?    // Alternative Firebase field name
    let isPlaceFree: Bool?
    // NEW: Location data
    let coordinates: EventCoordinates?
    let city: String?
    let state: String?
    let country: String?
    let address: String?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    // NEW: Popularity tracking fields
    let popularityScore: Double?
    let recentCheckIns: Int?
    let weeklyCheckIns: Int?
    let totalCheckIns: Int?
    let popularityUpdatedAt: Timestamp?
    
    // Convenience initializer
    init(placeName: String, placeLocation: String? = nil, placeImage: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.placeName = placeName
        self.placeLocation = placeLocation
        self.placeImage = placeImage
        self.imageUrl = nil
        self.firebaseImageUrl = nil
        self.isPlaceFree = nil
        // NEW: Initialize location fields
        self.coordinates = nil
        self.city = nil
        self.state = nil
        self.country = nil
        self.address = nil
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
        // NEW: Initialize popularity fields
        self.popularityScore = nil
        self.recentCheckIns = nil
        self.weeklyCheckIns = nil
        self.totalCheckIns = nil
        self.popularityUpdatedAt = nil
    }
}

// MARK: - Conversation Models
struct FirebaseConversation: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let participantOneId: String?
    let participantTwoId: String?
    let lastMessage: String?
    let lastMessageAt: Timestamp?
    let isRead: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(participantOneId: String?, participantTwoId: String?, lastMessage: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.participantOneId = participantOneId
        self.participantTwoId = participantTwoId
        self.lastMessage = lastMessage
        self.lastMessageAt = nil
        self.isRead = false
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
}

// MARK: - Message Models
struct FirebaseMessage: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let conversationId: String?
    let senderId: String?
    let messageText: String
    let sentAt: Timestamp?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(conversationId: String?, senderId: String?, messageText: String) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.conversationId = conversationId
        self.senderId = senderId
        self.messageText = messageText
        self.sentAt = Timestamp()
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    // Helper computed properties for UI
    var isSender: Bool {
        // This will be determined by the view when displaying messages
        // to avoid circular dependencies
        return false // Default to false, view should handle this logic
    }
    
    var timestamp: Date {
        return sentAt?.dateValue() ?? createdAt?.dateValue() ?? Date()
    }
}

// MARK: - Check-in Models
struct FirebaseCheckIn: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let userId: String?
    let eventId: String?
    let checkedInAt: Timestamp?
    let checkedOutAt: Timestamp?
    let isActive: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(userId: String?, eventId: String?) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.userId = userId
        self.eventId = eventId
        self.checkedInAt = Timestamp()
        self.checkedOutAt = nil
        self.isActive = true
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
}

// MARK: - Extensions for backward compatibility with existing UI code
extension FirebaseUser {
    var name: String {
        return firstName ?? "Unknown"
    }
    
    var profileImageName: String? {
        return profilePhoto
    }
    
    // Helper to get profile image URL from Firebase Storage
    var profileImageURL: URL? {
        guard let profilePhoto = profilePhoto, !profilePhoto.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if profilePhoto.hasPrefix("http") {
            return URL(string: profilePhoto)
        }
        
        // If it's a Firebase Storage reference, construct the URL with proper encoding
        let encodedPath = profilePhoto.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profilePhoto
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(encodedPath)?alt=media")
    }
}

extension FirebaseMember {
    var name: String {
        if let lastName = lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        }
        return firstName
    }
    
    var imageName: String {
        return profileImage?.isEmpty == false ? "person.crop.circle.fill" : "person.fill"
    }
    
    var approach: String {
        return approachTip ?? "Say hello"
    }
    
    // Helper to get profile image URL from Firebase Storage - Universal System
    var profileImageURL: URL? {
        guard let documentId = id, !documentId.isEmpty else { return nil }
        
        // Universal Firebase Storage API URL construction for ALL users
        // Works for both migrated users (UUID v4) and future users (Firebase Auth UID)
        let imageUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/profiles%2F\(documentId).jpg?alt=media"
        return URL(string: imageUrl)
    }
}

extension FirebaseEvent {
    var name: String {
        // Try eventName first, fallback to venueName, then "Unnamed Event"
        return eventName ?? venueName ?? "Unnamed Event"
    }
    
    var displayName: String {
        // Same fallback logic for display name
        return eventName ?? venueName ?? "Unnamed Event"
    }
    
    // Helper to get event image URL from Firebase Storage - Universal System
    var imageURL: URL? {
        let eventName = self.eventName ?? "Unknown"
        
        // PRIORITY 1: Check imageUrl field FIRST (this is what our fix script updated)
        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            print("🖼️ EVENT: Using imageUrl for '\(eventName)': \(imageUrl)")
            return URL(string: imageUrl)
        }
        
        // PRIORITY 2: Check firebaseImageUrl field
        if let firebaseImageUrl = firebaseImageUrl, !firebaseImageUrl.isEmpty {
            print("🖼️ EVENT: Using firebaseImageUrl for '\(eventName)': \(firebaseImageUrl)")
            return URL(string: firebaseImageUrl)
        }
        
        // PRIORITY 3: Try document ID-based Firebase Storage URL (standard pattern)
        if let documentId = id, !documentId.isEmpty {
            // Check common extensions
            let extensions = [".jpeg", ".jpg", ".png"]
            for ext in extensions {
                let imageUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/events%2F\(documentId)\(ext)?alt=media"
                print("🖼️ EVENT: Trying document ID pattern for '\(eventName)': \(imageUrl)")
                return URL(string: imageUrl)
            }
        }
        
        // PRIORITY 4: Try legacy image field with proper conversion
        if let image = image, !image.isEmpty {
            // If it's already a complete URL, use it
            if image.hasPrefix("http") {
                print("🖼️ EVENT: Using legacy URL for '\(eventName)': \(image)")
                return URL(string: image)
            }
            // If it's just a filename, construct the proper URL
            else {
                let properUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/events%2F\(image)?alt=media"
                print("🔄 EVENT: Converting filename for '\(eventName)': \(image) -> \(properUrl)")
                return URL(string: properUrl)
            }
        }
        
        print("❌ EVENT: No image URL available for '\(eventName)'")
        return nil
    }
}

extension FirebasePlace {
    var name: String {
        return placeName ?? "Unnamed Place"
    }
    
    // Helper to get place image URL from Firebase Storage - Universal System
    var imageURL: URL? {
        let placeName = self.placeName ?? "Unknown"
        
        // PRIORITY 1: Check imageUrl field FIRST (this is what our fix script updated)
        if let imageUrl = imageUrl, !imageUrl.isEmpty {
            print("🖼️ PLACE: Using imageUrl for '\(placeName)': \(imageUrl)")
            return URL(string: imageUrl)
        }
        
        // PRIORITY 2: Check firebaseImageUrl field
        if let firebaseImageUrl = firebaseImageUrl, !firebaseImageUrl.isEmpty {
            print("🖼️ PLACE: Using firebaseImageUrl for '\(placeName)': \(firebaseImageUrl)")
            return URL(string: firebaseImageUrl)
        }
        
        // PRIORITY 3: Try document ID-based Firebase Storage URL (standard pattern)
        if let documentId = id, !documentId.isEmpty {
            // Check common extensions
            let extensions = [".jpeg", ".jpg", ".png"]
            for ext in extensions {
                let imageUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/places%2F\(documentId)\(ext)?alt=media"
                print("🖼️ PLACE: Trying document ID pattern for '\(placeName)': \(imageUrl)")
                return URL(string: imageUrl)
            }
        }
        
        // PRIORITY 4: Try legacy placeImage field with proper conversion
        if let placeImage = placeImage, !placeImage.isEmpty {
            // If it's already a complete URL, use it
            if placeImage.hasPrefix("http") {
                print("🖼️ PLACE: Using legacy URL for '\(placeName)': \(placeImage)")
                return URL(string: placeImage)
            }
            // If it's just a filename, construct the proper URL
            else {
                let properUrl = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/places%2F\(placeImage)?alt=media"
                print("🔄 PLACE: Converting filename for '\(placeName)': \(placeImage) -> \(properUrl)")
                return URL(string: properUrl)
            }
        }
        
        print("❌ PLACE: No image URL available for '\(placeName)'")
        return nil
    }
}

// MARK: - Additional Firebase Services
// Note: FirebaseConversationsService is implemented in FirebaseServices.swift
// Note: UserPreferences is implemented in MembersView.swift

// MARK: - Check-in History Models
struct UserCheckInHistory: Codable, Hashable {
    let events: [String]?       // Array of event IDs
    let places: [String]?       // Array of place IDs
    let lastUpdated: Timestamp?
    
    // Computed properties for convenience
    var totalEvents: Int {
        return events?.count ?? 0
    }
    
    var totalPlaces: Int {
        return places?.count ?? 0
    }
    
    var totalCheckIns: Int {
        return totalEvents + totalPlaces
    }
    
    func hasCheckedInto(eventId: String) -> Bool {
        return events?.contains(eventId) ?? false
    }
    
    func hasCheckedInto(placeId: String) -> Bool {
        return places?.contains(placeId) ?? false
    }
} 