import Foundation

/*
 ADALO CONFIGURATION
 
 To connect your app to your Adalo database:
 
 1. Log into your Adalo dashboard (https://app.adalo.com)
 2. Go to your app settings
 3. Click on "App Access" and generate an API key
 4. Replace the placeholder values below with your actual credentials
 5. Set up your collections in Adalo to match the expected structure
 
 Required Collections in Adalo:
 - users (with fields: Email, First Name, Last Name, Profile Photo)
 - members (with fields: First Name, Age, City, Attracted To, Approach Tip, Instagram Handle, Profile Image, Is Active)
 - events (with fields: Name, Address, Description, Latitude, Longitude, Is Active)
 - conversations (with fields: Participant One ID, Participant Two ID, Last Message, Last Message At, Is Read)
 - messages (with fields: Conversation ID, Sender ID, Message Text, Sent At)
 - check_ins (with fields: User ID, Event ID, Checked In At, Checked Out At, Is Active)
*/

struct AdaloConfiguration {
    // MARK: - API Configuration (Now loaded from build settings via Bundle)
    static let apiKey: String = {
        // Try to read from Bundle.main.infoDictionary first (from build settings)
        if let key = Bundle.main.infoDictionary?["AdaloAPIKey"] as? String, !key.isEmpty {
            return key
        }
        
        // Read from environment variable for development
        if let envKey = ProcessInfo.processInfo.environment["ADALO_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // No fallback - configuration must be set
        fatalError("ADALO_API_KEY must be set in build configuration or environment variables")
    }()
    
    static let appID: String = {
        // Try to read from Bundle.main.infoDictionary first (from build settings)
        if let id = Bundle.main.infoDictionary?["AdaloAppID"] as? String, !id.isEmpty {
            return id
        }
        
        // Read from environment variable for development
        if let envID = ProcessInfo.processInfo.environment["ADALO_APP_ID"], !envID.isEmpty {
            return envID
        }
        
        // No fallback - configuration must be set
        fatalError("ADALO_APP_ID must be set in build configuration or environment variables")
    }()
    
    static let baseURL: String = {
        // Try to read from Bundle.main.infoDictionary first (from build settings)
        if let url = Bundle.main.infoDictionary?["AdaloBaseURL"] as? String, !url.isEmpty {
            return url
        }
        
        // Fallback to default URL
        return "https://api.adalo.com/v0"
    }()
    
    // MARK: - Collection Names
    // These should match your collection names in Adalo
    static let collections = [
        "users": "users",
        "members": "members", 
        "events": "events",
        "conversations": "conversations",
        "messages": "messages",
        "checkIns": "check_ins"
    ]
    
    // MARK: - Rate Limiting
    // Adalo API allows 5 requests per second
    static let rateLimitPerSecond = 5
    
    // MARK: - Feature Flags
    static let isDebugMenuEnabled: Bool = {
        if let flag = Bundle.main.infoDictionary?["EnableDebugMenu"] as? String {
            return flag.lowercased() == "yes" || flag.lowercased() == "true"
        }
        // Default to true in DEBUG builds, false in RELEASE
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    static let isLoggingEnabled: Bool = {
        if let flag = Bundle.main.infoDictionary?["EnableLogging"] as? String {
            return flag.lowercased() == "yes" || flag.lowercased() == "true"
        }
        // Default to true in DEBUG builds, false in RELEASE
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Environment Info
    static var currentEnvironment: String {
        #if DEBUG
        return "Development"
        #else
        return "Production"
        #endif
    }
    
    // MARK: - Validation
    static var isConfigured: Bool {
        return !apiKey.contains("YOUR_PRODUCTION") && !appID.contains("YOUR_PRODUCTION") && 
               !apiKey.isEmpty && !appID.isEmpty
    }
    
    static func validateConfiguration() -> (isValid: Bool, message: String) {
        guard !apiKey.isEmpty && !appID.isEmpty else {
            return (false, "API key and App ID cannot be empty")
        }
        
        guard !apiKey.contains("YOUR_PRODUCTION") && !apiKey.contains("YOUR_ADALO") else {
            return (false, "Please update your API credentials in the xcconfig files")
        }
        
        guard !appID.contains("YOUR_PRODUCTION") && !appID.contains("YOUR_ADALO") else {
            return (false, "Please update your App ID in the xcconfig files")
        }
        
        // Check if configuration is loaded from bundle or environment
        let fromBundle = Bundle.main.infoDictionary?["AdaloAPIKey"] != nil && Bundle.main.infoDictionary?["AdaloAppID"] != nil
        let fromEnvironment = ProcessInfo.processInfo.environment["ADALO_API_KEY"] != nil && ProcessInfo.processInfo.environment["ADALO_APP_ID"] != nil
        
        if fromBundle {
            return (true, "Configuration loaded from xcconfig files for \(currentEnvironment) environment")
        } else if fromEnvironment {
            return (true, "Configuration loaded from environment variables for \(currentEnvironment) environment")
        } else {
            return (true, "Configuration loaded from mixed sources for \(currentEnvironment) environment")
        }
    }
}

/*
 INSTRUCTIONS FOR SETTING UP YOUR ADALO DATABASE:
 
 1. In your Adalo app, create the following collections with these exact field names:
 
 USERS Collection:
 - Email (Email field)
 - First Name (Text field)
 - Last Name (Text field)  
 - Profile Photo (Image field)
 
 MEMBERS Collection:
 - First Name (Text field)
 - Age (Number field)
 - City (Text field)
 - Attracted To (Text field)
 - Approach Tip (Text field)
 - Instagram Handle (Text field)
 - Profile Image (Image field)
 - Is Active (True/False field)
 
 EVENTS Collection:
 - Name (Text field)
 - Address (Text field)
 - Description (Text field)
 - Latitude (Number field)
 - Longitude (Number field)
 - Is Active (True/False field)
 
 CONVERSATIONS Collection:
 - Participant One ID (Number field)
 - Participant Two ID (Number field)
 - Last Message (Text field)
 - Last Message At (Date & Time field)
 - Is Read (True/False field)
 
 MESSAGES Collection:
 - Conversation ID (Number field)
 - Sender ID (Number field)
 - Message Text (Text field)
 - Sent At (Date & Time field)
 
 CHECK_INS Collection:
 - User ID (Number field)
 - Event ID (Number field)
 - Checked In At (Date & Time field)
 - Checked Out At (Date & Time field)
 - Is Active (True/False field)
 
 2. Make sure all collections have the appropriate permissions set
 3. Test your API connection using the Adalo API documentation
*/ 