import Foundation

class CacheManager {
    static let shared = CacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    
    // Cache keys
    private let membersCacheKey = "shift.cache.members"
    private let eventsCacheKey = "shift.cache.events"
    private let placesCacheKey = "shift.cache.places"
    private let userProfileCacheKey = "shift.cache.userProfile"
    
    // Cache expiration keys
    private let membersExpirationKey = "shift.cache.members.expiration"
    private let eventsExpirationKey = "shift.cache.events.expiration"
    private let placesExpirationKey = "shift.cache.places.expiration"
    
    // Cache durations
    private let membersCacheDuration: TimeInterval = 3600 // 1 hour
    private let eventsCacheDuration: TimeInterval = 1800 // 30 minutes
    private let placesCacheDuration: TimeInterval = 3600 // 1 hour
    
    private init() {
        jsonEncoder.dateEncodingStrategy = .secondsSince1970
        jsonDecoder.dateDecodingStrategy = .secondsSince1970
    }
    
    // MARK: - Members Cache
    
    func cacheMembers(_ members: [FirebaseMember]) {
        do {
            let data = try jsonEncoder.encode(members)
            userDefaults.set(data, forKey: membersCacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: membersExpirationKey)
            print("💾 Cached \(members.count) members to persistent storage")
        } catch {
            print("❌ Failed to cache members: \(error)")
        }
    }
    
    func getCachedMembers() -> [FirebaseMember]? {
        // Check expiration
        let expirationTime = userDefaults.double(forKey: membersExpirationKey)
        if expirationTime > 0 {
            let expirationDate = Date(timeIntervalSince1970: expirationTime)
            if Date().timeIntervalSince(expirationDate) > membersCacheDuration {
                print("⏰ Members cache expired")
                clearMembersCache()
                return nil
            }
        }
        
        // Get cached data
        guard let data = userDefaults.data(forKey: membersCacheKey) else {
            return nil
        }
        
        do {
            let members = try jsonDecoder.decode([FirebaseMember].self, from: data)
            print("📱 Retrieved \(members.count) members from persistent cache")
            return members
        } catch {
            print("❌ Failed to decode cached members: \(error)")
            clearMembersCache()
            return nil
        }
    }
    
    func clearMembersCache() {
        userDefaults.removeObject(forKey: membersCacheKey)
        userDefaults.removeObject(forKey: membersExpirationKey)
    }
    
    // MARK: - Events Cache
    
    func cacheEvents(_ events: [FirebaseEvent]) {
        do {
            let data = try jsonEncoder.encode(events)
            userDefaults.set(data, forKey: eventsCacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: eventsExpirationKey)
            print("💾 Cached \(events.count) events to persistent storage")
        } catch {
            print("❌ Failed to cache events: \(error)")
        }
    }
    
    func getCachedEvents() -> [FirebaseEvent]? {
        // Check expiration
        let expirationTime = userDefaults.double(forKey: eventsExpirationKey)
        if expirationTime > 0 {
            let expirationDate = Date(timeIntervalSince1970: expirationTime)
            if Date().timeIntervalSince(expirationDate) > eventsCacheDuration {
                print("⏰ Events cache expired")
                clearEventsCache()
                return nil
            }
        }
        
        // Get cached data
        guard let data = userDefaults.data(forKey: eventsCacheKey) else {
            return nil
        }
        
        do {
            let events = try jsonDecoder.decode([FirebaseEvent].self, from: data)
            print("📱 Retrieved \(events.count) events from persistent cache")
            return events
        } catch {
            print("❌ Failed to decode cached events: \(error)")
            clearEventsCache()
            return nil
        }
    }
    
    func clearEventsCache() {
        userDefaults.removeObject(forKey: eventsCacheKey)
        userDefaults.removeObject(forKey: eventsExpirationKey)
    }
    
    // MARK: - Places Cache
    
    func cachePlaces(_ places: [FirebasePlace]) {
        do {
            let data = try jsonEncoder.encode(places)
            userDefaults.set(data, forKey: placesCacheKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: placesExpirationKey)
            print("💾 Cached \(places.count) places to persistent storage")
        } catch {
            print("❌ Failed to cache places: \(error)")
        }
    }
    
    func getCachedPlaces() -> [FirebasePlace]? {
        // Check expiration
        let expirationTime = userDefaults.double(forKey: placesExpirationKey)
        if expirationTime > 0 {
            let expirationDate = Date(timeIntervalSince1970: expirationTime)
            if Date().timeIntervalSince(expirationDate) > placesCacheDuration {
                print("⏰ Places cache expired")
                clearPlacesCache()
                return nil
            }
        }
        
        // Get cached data
        guard let data = userDefaults.data(forKey: placesCacheKey) else {
            return nil
        }
        
        do {
            let places = try jsonDecoder.decode([FirebasePlace].self, from: data)
            print("📱 Retrieved \(places.count) places from persistent cache")
            return places
        } catch {
            print("❌ Failed to decode cached places: \(error)")
            clearPlacesCache()
            return nil
        }
    }
    
    func clearPlacesCache() {
        userDefaults.removeObject(forKey: placesCacheKey)
        userDefaults.removeObject(forKey: placesExpirationKey)
    }
    
    // MARK: - User Profile Cache
    
    func cacheUserProfile(_ userData: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: userData)
            userDefaults.set(data, forKey: userProfileCacheKey)
            print("💾 Cached user profile to persistent storage")
        } catch {
            print("❌ Failed to cache user profile: \(error)")
        }
    }
    
    func getCachedUserProfile() -> [String: Any]? {
        guard let data = userDefaults.data(forKey: userProfileCacheKey) else {
            return nil
        }
        
        do {
            let userData = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            print("📱 Retrieved user profile from persistent cache")
            return userData
        } catch {
            print("❌ Failed to decode cached user profile: \(error)")
            return nil
        }
    }
    
    func clearUserProfileCache() {
        userDefaults.removeObject(forKey: userProfileCacheKey)
    }
    
    // MARK: - Clear All Cache
    
    func clearAllCache() {
        clearMembersCache()
        clearEventsCache()
        clearPlacesCache()
        clearUserProfileCache()
        print("🗑️ Cleared all persistent cache")
    }
} 