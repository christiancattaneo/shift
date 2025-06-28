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
    
    // Custom initializer for handling Firebase data
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle profilePhoto - could be String or Dictionary
        if let photoString = try? container.decode(String.self, forKey: .profilePhoto) {
            self.profilePhoto = photoString
        } else {
            // Try to decode as a dictionary and extract URL
            if let photoDict = try? container.decodeIfPresent([String: AnyDecodable].self, forKey: .profilePhoto),
               let urlValue = photoDict["url"]?.value as? String {
                // If it's just a filename, construct the Firebase Storage URL
                if !urlValue.hasPrefix("http") {
                    self.profilePhoto = "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/\(urlValue)"
                    print("🔗 Constructed Firebase URL from user filename: \(urlValue)")
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
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, email, username, fullName, firstName, profilePhoto, gender, attractedTo, age, city
        case howToApproachMe, isEventCreator, isEventAttendee, instagramHandle, subscribed, createdAt, updatedAt
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
    let age: Int?
    let city: String?
    let attractedTo: String?
    let approachTip: String?
    let instagramHandle: String?
    let profileImage: String?        // Legacy Adalo field (likely dead URLs)
    let profileImageUrl: String?     // NEW Firebase Storage field (working URLs)
    let firebaseImageUrl: String?    // Alternative Firebase field name
    let isActive: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Computed property to ensure unique ID for SwiftUI ForEach
    var uniqueID: String {
        // Use Firebase document ID first (most stable)
        if let id = id, !id.isEmpty {
            print("🆔 Using Firebase document ID for \(firstName): \(id)")
            return id
        }
        
        // Use userId if available
        if let userId = userId, !userId.isEmpty {
            print("🆔 Using userId for \(firstName): \(userId)")
            return userId
        }
        
        // Create a more unique fallback ID to prevent collisions
        let fallbackID = "\(firstName.lowercased())_\(age ?? 0)_\(city?.lowercased().prefix(3) ?? "none")_\(createdAt?.seconds ?? 0)_\(hashValue)"
        print("🆔 Generated fallback ID for \(firstName): \(fallbackID)")
        return fallbackID
    }
    
    // Convenience initializer
    init(userId: String? = nil, firstName: String, age: Int? = nil, city: String? = nil, attractedTo: String? = nil, approachTip: String? = nil, instagramHandle: String? = nil, profileImage: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.userId = userId
        self.firstName = firstName
        self.age = age
        self.city = city
        self.attractedTo = attractedTo
        self.approachTip = approachTip
        self.instagramHandle = instagramHandle
        self.profileImage = profileImage
        self.profileImageUrl = nil  // Initialize new Firebase Storage fields
        self.firebaseImageUrl = nil
        self.isActive = true
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
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
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
                // If it's just a filename, construct the Firebase Storage URL
                if !urlValue.hasPrefix("http") {
                    self.image = "https://storage.googleapis.com/shift-12948.firebasestorage.app/event_images/\(urlValue)"
                    print("🔗 Constructed Firebase URL from filename: \(urlValue)")
                } else {
                    self.image = urlValue
                    print("🔗 Using direct URL from image dict: \(urlValue)")
                }
            } else {
                self.image = nil
            }
        }
        
        // Standard fields
        self.eventName = try? container.decode(String.self, forKey: .eventName)
        self.venueName = try? container.decode(String.self, forKey: .venueName)
        self.eventLocation = try? container.decode(String.self, forKey: .eventLocation)
        self.isEventFree = try? container.decode(Bool.self, forKey: .isEventFree)
        self.eventCategory = try? container.decode(String.self, forKey: .eventCategory)
        self.eventDate = try? container.decode(String.self, forKey: .eventDate)
        self.place = try? container.decode(String.self, forKey: .place)
        self.createdAt = try? container.decode(Timestamp.self, forKey: .createdAt)
        self.updatedAt = try? container.decode(Timestamp.self, forKey: .updatedAt)
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
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    // Coding keys
    private enum CodingKeys: String, CodingKey {
        case id, eventName, venueName, eventLocation, eventStartTime, eventEndTime
        case image, imageUrl, firebaseImageUrl, isEventFree, eventCategory, eventDate, place, createdAt, updatedAt
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
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
}

// MARK: - Place Models
struct FirebasePlace: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let placeName: String?
    let placeLocation: String?
    let placeImage: String?
    let isPlaceFree: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(placeName: String, placeLocation: String? = nil, placeImage: String? = nil) {
        // Don't set self.id - @DocumentID is managed by Firestore
        self.placeName = placeName
        self.placeLocation = placeLocation
        self.placeImage = placeImage
        self.isPlaceFree = nil
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
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
        
        // If it's a Firebase Storage reference, construct the URL
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(profilePhoto)?alt=media")
    }
}

extension FirebaseMember {
    var name: String {
        return firstName
    }
    
    var imageName: String {
        return profileImage?.isEmpty == false ? "person.crop.circle.fill" : "person.fill"
    }
    
    var approach: String {
        return approachTip ?? "Say hello"
    }
    
    // Helper to get profile image URL from Firebase Storage
    var profileImageURL: URL? {
        // PRIORITY 1: Try Firebase Storage URLs first (these work!)
        if let firebaseUrl = profileImageUrl ?? firebaseImageUrl, !firebaseUrl.isEmpty {
            print("✅ Using Firebase Storage URL for \(firstName): \(firebaseUrl)")
            return URL(string: firebaseUrl)
        }
        
        // PRIORITY 2: Fallback to legacy profileImage field (likely dead Adalo URLs)
        guard let profileImage = profileImage, !profileImage.isEmpty else { 
            // Only log occasionally to avoid spam
            if firstName.starts(with: ["A", "B", "C", "D"]) {
                print("🔍 No profile image for member: \(firstName)")
            }
            return nil 
        }
        
        if profileImage.hasPrefix("http") {
            print("⚠️ Using legacy Adalo URL for \(firstName) (may be dead): \(profileImage)")
            return URL(string: profileImage)
        }
        
        // If it's a Firebase Storage reference, construct the URL
        let encodedPath = profileImage.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? profileImage
        let constructedURL = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(encodedPath)?alt=media"
        print("🔗 Constructed Firebase URL for \(firstName): \(constructedURL)")
        return URL(string: constructedURL)
    }
}

extension FirebaseEvent {
    var name: String {
        return eventName ?? "Unnamed Event"
    }
    
    var address: String? {
        return eventLocation
    }
    
    var displayName: String {
        return eventName ?? venueName ?? "Unnamed Event"
    }
    
    // Helper to get event image URL from Firebase Storage
    var imageURL: URL? {
        // PRIORITY 1: Try Firebase Storage URLs first (these work!)
        if let firebaseUrl = imageUrl ?? firebaseImageUrl, !firebaseUrl.isEmpty {
            print("✅ Using Firebase Storage URL for event \(displayName): \(firebaseUrl)")
            return URL(string: firebaseUrl)
        }
        
        // PRIORITY 2: Fallback to legacy image field (likely dead Adalo URLs)
        guard let image = image, !image.isEmpty else { 
            print("🔍 No image for event: \(displayName)")
            return nil 
        }
        
        if image.hasPrefix("http") {
            print("⚠️ Using legacy Adalo URL for event \(displayName) (may be dead): \(image)")
            return URL(string: image)
        }
        
        // If it's a Firebase Storage reference, construct the URL
        let encodedPath = image.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? image
        let constructedURL = "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(encodedPath)?alt=media"
        print("🔗 Constructed Firebase URL for event \(displayName): \(constructedURL)")
        return URL(string: constructedURL)
    }
}

extension FirebasePlace {
    var name: String {
        return placeName ?? "Unnamed Place"
    }
    
    var address: String? {
        return placeLocation
    }
    
    // Helper to get place image URL from Firebase Storage
    var imageURL: URL? {
        guard let placeImage = placeImage, !placeImage.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if placeImage.hasPrefix("http") {
            return URL(string: placeImage)
        }
        
        // If it's a Firebase Storage reference, construct the URL
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(placeImage)?alt=media")
    }
} 