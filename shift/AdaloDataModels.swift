import Foundation
import SwiftUI

// MARK: - User Models
struct AdaloUser: Identifiable, Codable, Hashable {
    let id: Int
    let email: String
    let password: String?
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
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case email = "Email"
        case password = "Password"
        case username = "Username"
        case fullName = "Full Name"
        case firstName = "First Name"
        case profilePhoto = "Photo"
        case gender = "Gender"
        case attractedTo = "Attracted to"
        case age = "Age"
        case city = "City"
        case howToApproachMe = "How to Approach Me"
        case isEventCreator = "Is Event Creator"
        case isEventAttendee = "Is Event Attendee"
        case instagramHandle = "Instagram Handle"
        case subscribed = "Subscribed"
        case createdAt = "Created"
        case updatedAt = "Updated"
    }
    
    // Convenience initializer for local use
    init(id: Int = 0, email: String, firstName: String?, fullName: String? = nil, profilePhoto: String? = nil, username: String? = nil, gender: String? = nil, attractedTo: String? = nil, age: Int? = nil, city: String? = nil, howToApproachMe: String? = nil, isEventCreator: Bool? = nil, instagramHandle: String? = nil) {
        self.id = id
        self.email = email
        self.password = nil
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
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Member Profile Models
struct AdaloMember: Identifiable, Codable, Hashable {
    let id: Int
    let userId: Int?
    let firstName: String
    let age: Int?
    let city: String?
    let attractedTo: String?
    let approachTip: String?
    let instagramHandle: String?
    let profileImage: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case userId = "User ID"
        case firstName = "First Name"
        case age = "Age"
        case city = "City"
        case attractedTo = "Attracted To"
        case approachTip = "Approach Tip"
        case instagramHandle = "Instagram Handle"
        case profileImage = "Profile Image"
        case isActive = "Is Active"
        case createdAt = "Created At"
        case updatedAt = "Updated At"
    }
    
    // Convenience initializer
    init(id: Int = 0, firstName: String, age: Int? = nil, city: String? = nil, attractedTo: String? = nil, approachTip: String? = nil, instagramHandle: String? = nil, profileImage: String? = nil) {
        self.id = id
        self.userId = nil
        self.firstName = firstName
        self.age = age
        self.city = city
        self.attractedTo = attractedTo
        self.approachTip = approachTip
        self.instagramHandle = instagramHandle
        self.profileImage = profileImage
        self.isActive = true
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Event Models
struct AdaloEvent: Identifiable, Codable, Hashable {
    let id: Int
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
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case eventName = "Event Name"
        case venueName = "Venue Name"
        case eventLocation = "Event Location"
        case eventStartTime = "Event Start Time"
        case eventEndTime = "Event End Time"
        case image = "Image"
        case isEventFree = "Is Event Free"
        case eventCategory = "Event Category"
        case eventDate = "Event DATE"
        case place = "Place"
        case createdAt = "Created"
        case updatedAt = "Updated"
    }
    
    // Convenience initializer
    init(id: Int = 0, eventName: String, venueName: String? = nil, eventLocation: String? = nil, eventStartTime: String? = nil, eventEndTime: String? = nil) {
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
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Place Models
struct AdaloPlace: Identifiable, Codable, Hashable {
    let id: Int
    let placeName: String?
    let placeLocation: String?
    let placeImage: String?
    let isPlaceFree: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case placeName = "Place Name"
        case placeLocation = "Place Locatioon" // Note: keeping the typo from CSV
        case placeImage = "Place Image"
        case isPlaceFree = "is place free"
        case createdAt = "Created"
        case updatedAt = "Updated"
    }
    
    // Convenience initializer
    init(id: Int = 0, placeName: String, placeLocation: String? = nil, placeImage: String? = nil) {
        self.id = id
        self.placeName = placeName
        self.placeLocation = placeLocation
        self.placeImage = placeImage
        self.isPlaceFree = nil
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Conversation Models
struct AdaloConversation: Identifiable, Codable, Hashable {
    let id: Int
    let participantOneId: Int?
    let participantTwoId: Int?
    let lastMessage: String?
    let lastMessageAt: String?
    let isRead: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case participantOneId = "Participant One ID"
        case participantTwoId = "Participant Two ID"
        case lastMessage = "Last Message"
        case lastMessageAt = "Last Message At"
        case isRead = "Is Read"
        case createdAt = "Created At"
        case updatedAt = "Updated At"
    }
    
    // Convenience initializer
    init(id: Int = 0, participantOneId: Int?, participantTwoId: Int?, lastMessage: String? = nil) {
        self.id = id
        self.participantOneId = participantOneId
        self.participantTwoId = participantTwoId
        self.lastMessage = lastMessage
        self.lastMessageAt = nil
        self.isRead = false
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - Message Models
struct AdaloMessage: Identifiable, Codable, Hashable {
    let id: Int
    let conversationId: Int?
    let senderId: Int?
    let messageText: String
    let sentAt: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case conversationId = "Conversation ID"
        case senderId = "Sender ID"
        case messageText = "Message Text"
        case sentAt = "Sent At"
        case createdAt = "Created At"
        case updatedAt = "Updated At"
    }
    
    // Convenience initializer
    init(id: Int = 0, conversationId: Int?, senderId: Int?, messageText: String) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.messageText = messageText
        self.sentAt = nil
        self.createdAt = nil
        self.updatedAt = nil
    }
    
    // Helper computed properties for UI
    var isSender: Bool {
        // Compare with current logged-in Firebase user ID
        guard let senderId = senderId else { return false }
        return String(senderId) == FirebaseUserSession.shared.currentUser?.id
    }
    
    var timestamp: Date {
        // Convert sentAt or createdAt string to Date
        let formatter = ISO8601DateFormatter()
        if let sentAt = sentAt, let date = formatter.date(from: sentAt) {
            return date
        } else if let createdAt = createdAt, let date = formatter.date(from: createdAt) {
            return date
        }
        return Date()
    }
}

// MARK: - Check-in Models
struct AdaloCheckIn: Identifiable, Codable, Hashable {
    let id: Int
    let userId: Int?
    let eventId: Int?
    let checkedInAt: String?
    let checkedOutAt: String?
    let isActive: Bool?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case userId = "User ID"
        case eventId = "Event ID"
        case checkedInAt = "Checked In At"
        case checkedOutAt = "Checked Out At"
        case isActive = "Is Active"
        case createdAt = "Created At"
        case updatedAt = "Updated At"
    }
    
    // Convenience initializer
    init(id: Int = 0, userId: Int?, eventId: Int?) {
        self.id = id
        self.userId = userId
        self.eventId = eventId
        self.checkedInAt = nil
        self.checkedOutAt = nil
        self.isActive = true
        self.createdAt = nil
        self.updatedAt = nil
    }
}

// MARK: - User Session Management (Firebase Bridge)
// This provides backwards compatibility while using Firebase under the hood
class UserSession: ObservableObject {
    static let shared = UserSession()
    
    @Published var currentUser: AdaloUser?
    @Published var isLoggedIn: Bool = false
    
    private let firebaseSession = FirebaseUserSession.shared
    
    private init() {
        // Bridge Firebase session to Adalo format for backwards compatibility
        firebaseSession.$currentUser
            .compactMap { $0 }
            .map { firebaseUser in
                AdaloUser(
                    id: Int(firebaseUser.id?.hashValue ?? 0),
                    email: firebaseUser.email,
                    firstName: firebaseUser.firstName,
                    fullName: firebaseUser.fullName,
                    profilePhoto: firebaseUser.profilePhoto,
                    username: firebaseUser.username,
                    gender: firebaseUser.gender,
                    attractedTo: firebaseUser.attractedTo,
                    age: firebaseUser.age,
                    city: firebaseUser.city,
                    howToApproachMe: firebaseUser.howToApproachMe,
                    isEventCreator: firebaseUser.isEventCreator,
                    instagramHandle: firebaseUser.instagramHandle
                )
            }
            .assign(to: &$currentUser)
        
        firebaseSession.$isLoggedIn
            .assign(to: &$isLoggedIn)
    }
    
    func login(user: AdaloUser) {
        // This is now handled by Firebase Auth
        // This method is kept for backwards compatibility but doesn't do anything
        print("⚠️ login(user:) is deprecated. Use Firebase authentication instead.")
    }
    
    func logout() {
        firebaseSession.signOut()
    }
    
    func loadSavedUser() {
        firebaseSession.loadSavedUser()
    }
}

// MARK: - Extension for backward compatibility with existing UI code
extension AdaloUser {
    var name: String {
        return firstName ?? "Unknown"
    }
    
    var profileImageName: String? {
        return profilePhoto
    }
    
    // Helper to get profile image URL from Adalo
    var profileImageURL: URL? {
        guard let profilePhoto = profilePhoto, !profilePhoto.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if profilePhoto.hasPrefix("http") {
            return URL(string: profilePhoto)
        }
        
        // If it's a relative Adalo URL, construct the full URL
        return URL(string: "https://api.adalo.com/v0/\(profilePhoto)")
    }
}

extension AdaloMember {
    var name: String {
        return firstName
    }
    
    var imageName: String {
        // Return system icon name as fallback
        return profileImage?.isEmpty == false ? "person.crop.circle.fill" : "person.fill"
    }
    
    var approach: String {
        return approachTip ?? "Say hello"
    }
    
    // Helper to get profile image URL from Adalo
    var profileImageURL: URL? {
        guard let profileImage = profileImage, !profileImage.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if profileImage.hasPrefix("http") {
            return URL(string: profileImage)
        }
        
        // If it's a relative Adalo URL, construct the full URL  
        return URL(string: "https://api.adalo.com/v0/\(profileImage)")
    }
}

extension AdaloEvent {
    var name: String {
        return eventName ?? "Unnamed Event"
    }
    
    var address: String? {
        return eventLocation
    }
    
    var displayName: String {
        return eventName ?? venueName ?? "Unnamed Event"
    }
    
    // Helper to get event image URL from Adalo
    var imageURL: URL? {
        guard let image = image, !image.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if image.hasPrefix("http") {
            return URL(string: image)
        }
        
        // If it's a relative Adalo URL, construct the full URL
        return URL(string: "https://api.adalo.com/v0/\(image)")
    }
}

extension AdaloPlace {
    var name: String {
        return placeName ?? "Unnamed Place"
    }
    
    var address: String? {
        return placeLocation
    }
    
    // Helper to get place image URL from Adalo
    var imageURL: URL? {
        guard let placeImage = placeImage, !placeImage.isEmpty else { return nil }
        
        // If it's already a complete URL, use it
        if placeImage.hasPrefix("http") {
            return URL(string: placeImage)
        }
        
        // If it's a relative Adalo URL, construct the full URL
        return URL(string: "https://api.adalo.com/v0/\(placeImage)")
    }
} 