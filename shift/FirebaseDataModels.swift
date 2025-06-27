import Foundation
import SwiftUI
import FirebaseFirestore

// MARK: - User Models
struct FirebaseUser: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let email: String
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
    
    // Convenience initializer for local use
    init(id: String? = nil, email: String, firstName: String?, fullName: String? = nil, profilePhoto: String? = nil, username: String? = nil, gender: String? = nil, attractedTo: String? = nil, age: Int? = nil, city: String? = nil, howToApproachMe: String? = nil, isEventCreator: Bool? = nil, instagramHandle: String? = nil) {
        self.id = id
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
    let profileImage: String?
    let isActive: Bool?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(id: String? = nil, userId: String? = nil, firstName: String, age: Int? = nil, city: String? = nil, attractedTo: String? = nil, approachTip: String? = nil, instagramHandle: String? = nil, profileImage: String? = nil) {
        self.id = id
        self.userId = userId
        self.firstName = firstName
        self.age = age
        self.city = city
        self.attractedTo = attractedTo
        self.approachTip = approachTip
        self.instagramHandle = instagramHandle
        self.profileImage = profileImage
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
    let image: String?
    let isEventFree: Bool?
    let eventCategory: String?
    let eventDate: String?
    let place: String?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Convenience initializer
    init(id: String? = nil, eventName: String, venueName: String? = nil, eventLocation: String? = nil, eventStartTime: String? = nil, eventEndTime: String? = nil) {
        self.id = id
        self.eventName = eventName
        self.venueName = venueName
        self.eventLocation = eventLocation
        self.eventStartTime = eventStartTime
        self.eventEndTime = eventEndTime
        self.image = nil
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
    init(id: String? = nil, placeName: String, placeLocation: String? = nil, placeImage: String? = nil) {
        self.id = id
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
    init(id: String? = nil, participantOneId: String?, participantTwoId: String?, lastMessage: String? = nil) {
        self.id = id
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
    init(id: String? = nil, conversationId: String?, senderId: String?, messageText: String) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.messageText = messageText
        self.sentAt = Timestamp()
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    // Helper computed properties for UI
    var isSender: Bool {
        return senderId == FirebaseUserSession.shared.currentUser?.id
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
    init(id: String? = nil, userId: String?, eventId: String?) {
        self.id = id
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
        guard let profileImage = profileImage, !profileImage.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if profileImage.hasPrefix("http") {
            return URL(string: profileImage)
        }
        
        // If it's a Firebase Storage reference, construct the URL
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(profileImage)?alt=media")
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
        guard let image = image, !image.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if image.hasPrefix("http") {
            return URL(string: image)
        }
        
        // If it's a Firebase Storage reference, construct the URL
        return URL(string: "https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/\(image)?alt=media")
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