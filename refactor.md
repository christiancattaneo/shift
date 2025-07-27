# Shift App - Comprehensive Refactoring Plan

## Executive Summary

This document outlines a comprehensive refactoring plan for the Shift dating/social discovery app based on industry best practices. The app is well-architected but has opportunities for improved maintainability, scalability, performance, and code organization.

**Current State**: 
- iOS app built with SwiftUI + Firebase backend
- 720+ users, 166 events, 57 places
- Recently migrated from Adalo to Firebase
- Sophisticated dating/social features with location-based discovery

**Refactoring Scope**: Architecture improvements, code organization, performance optimization, and maintainability enhancements.

---

## 1. Architecture & Design Patterns

### 1.1 MVVM Architecture Enhancement

**Current Issue**: Services are doing too much - mixing data access, business logic, and UI state management.

**Proposed Solution**: Implement proper MVVM separation
```swift
// ViewModels for each major screen
class MembersViewModel: ObservableObject {
    @Published var members: [FirebaseMember] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let membersService: MembersServiceProtocol
    private let locationService: LocationServiceProtocol
    
    func loadCompatibleMembers() { ... }
    func searchMembers(query: String) { ... }
}

// Protocol-based services for testability
protocol MembersServiceProtocol {
    func getCompatibleMembers(for user: FirebaseUser) async throws -> [FirebaseMember]
    func searchMembers(query: String) async throws -> [FirebaseMember]
}
```

**Benefits**: Better testability, clearer separation of concerns, reusable ViewModels

### 1.2 Dependency Injection Container

**Current Issue**: Singleton services create tight coupling and make testing difficult.

**Proposed Solution**: Implement dependency injection
```swift
protocol DependencyContainer {
    var authService: AuthServiceProtocol { get }
    var membersService: MembersServiceProtocol { get }
    var locationService: LocationServiceProtocol { get }
    var analyticsService: AnalyticsServiceProtocol { get }
}

class DefaultDependencyContainer: DependencyContainer {
    lazy var authService: AuthServiceProtocol = FirebaseAuthService()
    lazy var membersService: MembersServiceProtocol = FirebaseMembersService()
    // ... other services
}

// Usage in Views
struct MembersView: View {
    @StateObject private var viewModel: MembersViewModel
    
    init(container: DependencyContainer = DefaultDependencyContainer()) {
        _viewModel = StateObject(wrappedValue: MembersViewModel(
            membersService: container.membersService,
            locationService: container.locationService
        ))
    }
}
```

### 1.3 Repository Pattern Implementation

**Current Issue**: Direct Firebase calls scattered throughout services.

**Proposed Solution**: Abstract data access layer
```swift
protocol UserRepositoryProtocol {
    func fetchUser(uid: String) async throws -> FirebaseUser
    func updateUser(_ user: FirebaseUser) async throws
    func deleteUser(uid: String) async throws
}

class FirebaseUserRepository: UserRepositoryProtocol {
    private let firestore = Firestore.firestore()
    
    func fetchUser(uid: String) async throws -> FirebaseUser {
        // Firebase-specific implementation
    }
}

class MockUserRepository: UserRepositoryProtocol {
    // Mock implementation for testing
}
```

---

## 2. Code Organization & Structure

### 2.1 Feature-Based Module Organization

**Current Issue**: Files organized by type rather than feature.

**Proposed Solution**: Restructure into feature modules
```
shift/
├── Core/
│   ├── Services/
│   ├── Models/
│   ├── Utilities/
│   └── Extensions/
├── Features/
│   ├── Authentication/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Services/
│   │   └── Models/
│   ├── Members/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Services/
│   │   └── Models/
│   ├── CheckIns/
│   ├── Profile/
│   └── Chat/
├── Shared/
│   ├── Components/
│   ├── Styles/
│   └── Resources/
└── App/
    ├── shiftApp.swift
    ├── AppDelegate.swift
    └── Configuration/
```

### 2.2 Create Reusable UI Components

**Current Issue**: UI code duplication across views.

**Proposed Solution**: Build component library
```swift
// Reusable card component
struct MemberCard: View {
    let member: FirebaseMember
    let onTap: () -> Void
    
    var body: some View {
        // Reusable card implementation
    }
}

// Design system tokens
enum DesignTokens {
    enum Colors {
        static let primary = Color("Primary")
        static let secondary = Color("Secondary")
        static let background = Color("Background")
    }
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }
    
    enum Typography {
        static let heading1 = Font.system(size: 32, weight: .bold)
        static let heading2 = Font.system(size: 24, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
    }
}
```

### 2.3 Configuration Management

**Current Issue**: Hardcoded values scattered throughout code.

**Proposed Solution**: Centralized configuration
```swift
enum AppConfiguration {
    enum Firebase {
        static let projectId = "shift-12948"
        static let storageBucket = "shift-12948.appspot.com"
    }
    
    enum Features {
        static let maxCheckInDistance: Double = 100 // meters
        static let maxMemberAge = 35
        static let minMemberAge = 18
        static let maxSearchRadius: Double = 50000 // meters
    }
    
    enum UI {
        static let maxProfileImageSize: CGFloat = 300
        static let cardCornerRadius: CGFloat = 12
        static let animationDuration: Double = 0.3
    }
}
```

---

## 3. Data Layer Improvements

### 3.1 Core Data Integration for Offline Support

**Current Issue**: No offline data persistence, poor performance when network is slow.

**Proposed Solution**: Implement Core Data with Firebase sync
```swift
class DataSyncManager {
    private let coreDataStack: CoreDataStack
    private let firebaseSync: FirebaseSyncService
    
    func syncUsers() async throws {
        // 1. Fetch from Firebase
        // 2. Update Core Data
        // 3. Notify UI of changes
    }
    
    func getUsers(fetchFromRemote: Bool = false) async throws -> [FirebaseUser] {
        if fetchFromRemote {
            return try await syncUsers()
        } else {
            return try await coreDataStack.fetchUsers()
        }
    }
}
```

### 3.2 Improved Error Handling

**Current Issue**: Generic error handling, no user-friendly error messages.

**Proposed Solution**: Structured error handling system
```swift
enum AppError: LocalizedError {
    case networkError(NetworkError)
    case authenticationError(AuthError)
    case validationError(ValidationError)
    case coreDataError(CoreDataError)
    
    var errorDescription: String? {
        switch self {
        case .networkError(.noConnection):
            return "Please check your internet connection and try again."
        case .authenticationError(.invalidCredentials):
            return "Invalid email or password. Please try again."
        case .validationError(.missingRequiredField(let field)):
            return "\(field) is required."
        }
    }
    
    var recoverySuggestion: String? {
        // User-friendly recovery suggestions
    }
}

// Error handling service
class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    
    func handle(_ error: Error) {
        // Log error for debugging
        Logger.error("Error occurred: \(error)")
        
        // Convert to user-friendly error
        currentError = AppError.from(error)
        
        // Send to analytics
        AnalyticsService.shared.logError(error)
    }
}
```

### 3.3 Data Validation Layer

**Current Issue**: Data validation scattered throughout the app.

**Proposed Solution**: Centralized validation
```swift
protocol Validatable {
    func validate() throws
}

struct UserProfile: Validatable {
    let firstName: String
    let email: String
    let age: Int
    
    func validate() throws {
        guard !firstName.isEmpty else {
            throw ValidationError.missingRequiredField("First Name")
        }
        
        guard email.isValidEmail else {
            throw ValidationError.invalidFormat("Email")
        }
        
        guard age >= 18 && age <= 100 else {
            throw ValidationError.outOfRange("Age", min: 18, max: 100)
        }
    }
}

class ValidationService {
    static func validate<T: Validatable>(_ item: T) throws {
        try item.validate()
    }
}
```

---

## 4. Performance Optimizations

### 4.1 Image Loading & Caching

**Current Issue**: Images load slowly, no caching, poor memory management.

**Proposed Solution**: Implement proper image caching
```swift
class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    func loadImage(from url: URL) async throws -> UIImage {
        // 1. Check memory cache
        if let cachedImage = cache.object(forKey: url.absoluteString as NSString) {
            return cachedImage
        }
        
        // 2. Check disk cache
        if let diskImage = try? loadFromDisk(url: url) {
            cache.setObject(diskImage, forKey: url.absoluteString as NSString)
            return diskImage
        }
        
        // 3. Download from network
        let image = try await downloadImage(from: url)
        
        // 4. Cache in memory and disk
        cache.setObject(image, forKey: url.absoluteString as NSString)
        try? saveToDisk(image: image, url: url)
        
        return image
    }
}

// Usage in SwiftUI
struct CachedAsyncImage: View {
    let url: URL?
    let placeholder: Image
    
    @State private var image: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
            } else {
                placeholder
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else { return }
        
        isLoading = true
        Task {
            do {
                let loadedImage = try await ImageCache.shared.loadImage(from: url)
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}
```

### 4.2 Lazy Loading & Pagination

**Current Issue**: Loading all data at once, causing memory issues and slow loading.

**Proposed Solution**: Implement proper pagination
```swift
class PaginatedDataLoader<T: Identifiable> {
    private let pageSize: Int
    private let loadPage: (Int) async throws -> [T]
    
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var hasMoreData = true
    
    init(pageSize: Int = 20, loadPage: @escaping (Int) async throws -> [T]) {
        self.pageSize = pageSize
        self.loadPage = loadPage
    }
    
    func loadNextPage() async {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        do {
            let newItems = try await loadPage(items.count / pageSize)
            
            await MainActor.run {
                self.items.append(contentsOf: newItems)
                self.hasMoreData = newItems.count == pageSize
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
```

### 4.3 Memory Management

**Current Issue**: Potential memory leaks with Firebase listeners and image loading.

**Proposed Solution**: Proper resource management
```swift
class ResourceManager {
    private var listeners: [ListenerRegistration] = []
    private var tasks: [Task<Void, Never>] = []
    
    func addListener(_ listener: ListenerRegistration) {
        listeners.append(listener)
    }
    
    func addTask(_ task: Task<Void, Never>) {
        tasks.append(task)
    }
    
    func cleanup() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
        
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
    
    deinit {
        cleanup()
    }
}

// Usage in ViewModels
class MembersViewModel: ObservableObject {
    private let resourceManager = ResourceManager()
    
    func startListening() {
        let listener = firestore.collection("users").addSnapshotListener { ... }
        resourceManager.addListener(listener)
    }
    
    deinit {
        resourceManager.cleanup()
    }
}
```

---

## 5. Security Enhancements

### 5.1 Input Validation & Sanitization

**Current Issue**: User input not properly validated on client side.

**Proposed Solution**: Comprehensive input validation
```swift
class InputValidator {
    static func sanitizeText(_ text: String) -> String {
        return text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    static func validateEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func validatePassword(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []
        
        if password.count < 8 {
            issues.append("Password must be at least 8 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            issues.append("Password must contain an uppercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            issues.append("Password must contain a number")
        }
        
        return PasswordValidationResult(isValid: issues.isEmpty, issues: issues)
    }
}
```

### 5.2 Sensitive Data Protection

**Current Issue**: Sensitive data not properly protected in memory/storage.

**Proposed Solution**: Keychain integration for sensitive data
```swift
class KeychainService {
    private let keychain = Keychain(service: "com.christiancattaneo.shift")
    
    func store(_ data: Data, for key: String) throws {
        try keychain.set(data, key: key)
    }
    
    func retrieve(for key: String) throws -> Data? {
        return try keychain.getData(key)
    }
    
    func delete(for key: String) throws {
        try keychain.remove(key)
    }
}

// Usage for auth tokens
class AuthTokenManager {
    private let keychain = KeychainService()
    
    func storeAuthToken(_ token: String) throws {
        let data = token.data(using: .utf8)!
        try keychain.store(data, for: "auth_token")
    }
    
    func getAuthToken() throws -> String? {
        guard let data = try keychain.retrieve(for: "auth_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

---

## 6. Testing Infrastructure

### 6.1 Unit Testing Setup

**Current Issue**: No unit tests for business logic.

**Proposed Solution**: Comprehensive unit testing
```swift
// Example test for MembersViewModel
class MembersViewModelTests: XCTestCase {
    var viewModel: MembersViewModel!
    var mockMembersService: MockMembersService!
    var mockLocationService: MockLocationService!
    
    override func setUp() {
        super.setUp()
        mockMembersService = MockMembersService()
        mockLocationService = MockLocationService()
        viewModel = MembersViewModel(
            membersService: mockMembersService,
            locationService: mockLocationService
        )
    }
    
    func testLoadCompatibleMembers_Success() async {
        // Given
        let expectedMembers = [createMockMember()]
        mockMembersService.compatibleMembersResult = .success(expectedMembers)
        
        // When
        await viewModel.loadCompatibleMembers()
        
        // Then
        XCTAssertEqual(viewModel.members.count, 1)
        XCTAssertEqual(viewModel.members.first?.firstName, "Test User")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
    
    func testLoadCompatibleMembers_Error() async {
        // Given
        mockMembersService.compatibleMembersResult = .failure(NetworkError.noConnection)
        
        // When
        await viewModel.loadCompatibleMembers()
        
        // Then
        XCTAssertTrue(viewModel.members.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.error)
    }
}
```

### 6.2 UI Testing

**Current Issue**: No automated UI testing.

**Proposed Solution**: UI test suite for critical flows
```swift
class ShiftUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    func testLoginFlow() {
        // Test successful login
        app.textFields["Email"].tap()
        app.textFields["Email"].typeText("test@example.com")
        
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("password123")
        
        app.buttons["Login"].tap()
        
        // Verify navigation to main screen
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }
    
    func testMemberDiscoveryFlow() {
        // Test member browsing and interaction
        loginTestUser()
        
        app.tabBars.buttons["Members"].tap()
        
        // Wait for members to load
        let firstMemberCard = app.scrollViews.buttons.firstMatch
        XCTAssertTrue(firstMemberCard.waitForExistence(timeout: 5))
        
        // Test member detail view
        firstMemberCard.tap()
        XCTAssertTrue(app.buttons["Start Conversation"].exists)
    }
}
```

---

## 7. Monitoring & Analytics

### 7.1 Comprehensive Logging

**Current Issue**: Debug print statements scattered throughout code.

**Proposed Solution**: Structured logging system
```swift
import OSLog

enum LogCategory: String {
    case authentication = "Authentication"
    case networking = "Networking"
    case userInterface = "UI"
    case dataAccess = "DataAccess"
    case performance = "Performance"
}

class Logger {
    private static let subsystem = "com.christiancattaneo.shift"
    
    static func debug(_ message: String, category: LogCategory = .userInterface) {
        let logger = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log("%@", log: logger, type: .debug, message)
    }
    
    static func info(_ message: String, category: LogCategory = .userInterface) {
        let logger = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log("%@", log: logger, type: .info, message)
    }
    
    static func error(_ message: String, category: LogCategory = .userInterface) {
        let logger = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log("%@", log: logger, type: .error, message)
    }
}

// Usage
Logger.info("User successfully logged in", category: .authentication)
Logger.error("Failed to load members: \(error)", category: .networking)
```

### 7.2 Performance Monitoring

**Current Issue**: No performance monitoring for app bottlenecks.

**Proposed Solution**: Performance tracking
```swift
class PerformanceMonitor {
    static func measure<T>(
        operation: String,
        category: LogCategory = .performance,
        block: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            Logger.info("Operation '\(operation)' took \(executionTime)s", category: category)
            
            // Send to analytics if operation is slow
            if executionTime > 1.0 {
                AnalyticsService.shared.logSlowOperation(operation, duration: executionTime)
            }
        }
        
        return try block()
    }
    
    static func measureAsync<T>(
        operation: String,
        category: LogCategory = .performance,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            Logger.info("Async operation '\(operation)' took \(executionTime)s", category: category)
        }
        
        return try await block()
    }
}

// Usage
let members = await PerformanceMonitor.measureAsync(operation: "LoadCompatibleMembers") {
    try await membersService.getCompatibleMembers()
}
```

### 7.3 User Analytics

**Current Issue**: No user behavior tracking for product insights.

**Proposed Solution**: Privacy-focused analytics
```swift
protocol AnalyticsServiceProtocol {
    func logEvent(_ event: AnalyticsEvent)
    func logUserProperty(_ property: String, value: String)
    func logError(_ error: Error)
}

enum AnalyticsEvent {
    case screenView(screenName: String)
    case userAction(action: String, screen: String)
    case memberInteraction(action: String, memberAge: Int?)
    case checkIn(eventType: String, location: String)
    case conversationStarted
    case profileUpdated
    
    var name: String {
        switch self {
        case .screenView: return "screen_view"
        case .userAction: return "user_action"
        case .memberInteraction: return "member_interaction"
        case .checkIn: return "check_in"
        case .conversationStarted: return "conversation_started"
        case .profileUpdated: return "profile_updated"
        }
    }
    
    var parameters: [String: Any] {
        switch self {
        case .screenView(let screenName):
            return ["screen_name": screenName]
        case .userAction(let action, let screen):
            return ["action": action, "screen": screen]
        case .memberInteraction(let action, let age):
            var params: [String: Any] = ["action": action]
            if let age = age {
                params["member_age_range"] = ageRange(for: age)
            }
            return params
        case .checkIn(let eventType, let location):
            return ["event_type": eventType, "location": location]
        case .conversationStarted, .profileUpdated:
            return [:]
        }
    }
    
    private func ageRange(for age: Int) -> String {
        switch age {
        case 18...24: return "18-24"
        case 25...30: return "25-30"
        case 31...35: return "31-35"
        default: return "other"
        }
    }
}
```

---

## 8. Accessibility Improvements

### 8.1 VoiceOver Support

**Current Issue**: Limited accessibility support for visually impaired users.

**Proposed Solution**: Comprehensive accessibility
```swift
// Enhanced member card with accessibility
struct MemberCard: View {
    let member: FirebaseMember
    
    var body: some View {
        VStack {
            AsyncImage(url: member.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .accessibility(label: Text("Profile photo of \(member.firstName)"))
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .accessibility(label: Text("Profile photo loading"))
            }
            
            Text(member.firstName)
                .font(.headline)
                .accessibility(addTraits: .isHeader)
            
            Text("\(member.age) years old")
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(member.firstName), \(member.age) years old")
        .accessibilityHint("Double tap to view profile")
        .accessibilityAddTraits(.isButton)
    }
}

// Form accessibility
struct SignUpForm: View {
    @State private var firstName = ""
    @State private var email = ""
    
    var body: some View {
        Form {
            TextField("First Name", text: $firstName)
                .accessibility(label: Text("First Name"))
                .accessibility(hint: Text("Enter your first name"))
            
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .accessibility(label: Text("Email Address"))
                .accessibility(hint: Text("Enter your email address"))
        }
        .navigationTitle("Sign Up")
        .accessibility(identifier: "SignUpForm")
    }
}
```

### 8.2 Dynamic Type Support

**Current Issue**: Fixed font sizes don't scale with user preferences.

**Proposed Solution**: Dynamic Type support
```swift
extension Font {
    static func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .default)
    }
}

// Usage in components
struct MemberCard: View {
    var body: some View {
        VStack {
            Text(member.firstName)
                .font(.scaledFont(size: 18, weight: .semibold))
                .dynamicTypeSize(.xSmall ... .accessibility3)
            
            Text(member.approachTip)
                .font(.scaledFont(size: 14))
                .dynamicTypeSize(.xSmall ... .accessibility3)
        }
    }
}
```

---

## 9. Internationalization & Localization

### 9.1 String Localization

**Current Issue**: Hardcoded English strings throughout the app.

**Proposed Solution**: Full localization support
```swift
// Localizable.strings (English)
"members.title" = "Members";
"members.noResults" = "No members found";
"members.searchPlaceholder" = "Search members...";
"profile.edit" = "Edit Profile";
"checkIn.success" = "Successfully checked in!";

// Localizable.strings (Spanish)
"members.title" = "Miembros";
"members.noResults" = "No se encontraron miembros";
"members.searchPlaceholder" = "Buscar miembros...";
"profile.edit" = "Editar Perfil";
"checkIn.success" = "¡Check-in exitoso!";

// Centralized strings enum
enum Strings {
    enum Members {
        static let title = NSLocalizedString("members.title", comment: "Members screen title")
        static let noResults = NSLocalizedString("members.noResults", comment: "No members found message")
        static let searchPlaceholder = NSLocalizedString("members.searchPlaceholder", comment: "Search placeholder")
    }
    
    enum Profile {
        static let edit = NSLocalizedString("profile.edit", comment: "Edit profile button")
    }
    
    enum CheckIn {
        static let success = NSLocalizedString("checkIn.success", comment: "Check-in success message")
    }
}

// Usage
Text(Strings.Members.title)
    .font(.largeTitle)
```

---

## 10. Backend & Firebase Improvements

### 10.1 Cloud Functions Optimization

**Current Issue**: Cloud Functions could be more efficient and better organized.

**Proposed Solution**: Optimize and restructure functions
```javascript
// functions/src/index.js - Better organization
const { onRequest, onCall, onDocumentCreated } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');

// Modular function organization
const userFunctions = require('./modules/users');
const memberFunctions = require('./modules/members');
const analyticsManager = require('./modules/analytics');

// Export organized functions
exports.users = userFunctions;
exports.members = memberFunctions;
exports.analytics = analyticsManager;

// functions/src/modules/users.js
const { onCall } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

exports.updateProfile = onCall(async (request) => {
  // Input validation
  const { uid, profileData } = request.data;
  
  if (!uid || !profileData) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required parameters'
    );
  }
  
  // Validate user permissions
  if (request.auth?.uid !== uid) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Unauthorized access'
    );
  }
  
  try {
    // Update user profile with validation
    await admin.firestore()
      .collection('users')
      .doc(uid)
      .update({
        ...profileData,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    
    return { success: true };
  } catch (error) {
    console.error('Error updating profile:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update profile'
    );
  }
});
```

### 10.2 Firestore Security Rules Enhancement

**Current Issue**: Security rules could be more granular and secure.

**Proposed Solution**: Enhanced security rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(resource) {
      return request.auth.uid == resource.data.uid;
    }
    
    function isValidUser(data) {
      return data.keys().hasAll(['firstName', 'email', 'city']) &&
             data.firstName is string &&
             data.email is string &&
             data.city is string &&
             data.firstName.size() > 0 &&
             data.email.matches('.*@.*\\..*');
    }
    
    function hasValidAge(data) {
      return data.age is int &&
             data.age >= 18 &&
             data.age <= 100;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && 
                   isOwner(resource) &&
                   isValidUser(request.resource.data) &&
                   hasValidAge(request.resource.data);
      allow update: if isAuthenticated() && 
                   isOwner(resource) &&
                   isValidUser(request.resource.data) &&
                   hasValidAge(request.resource.data);
      allow delete: if isAuthenticated() && isOwner(resource);
    }
    
    // Events collection
    match /events/{eventId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
                   request.resource.data.keys().hasAll(['name', 'coordinates', 'eventDate']) &&
                   request.resource.data.name is string &&
                   request.resource.data.name.size() > 0;
      allow update: if isAuthenticated() &&
                   request.resource.data.keys().hasAll(['name', 'coordinates', 'eventDate']);
      allow delete: if false; // Only allow deletion through Cloud Functions
    }
    
    // Check-ins collection
    match /checkIns/{checkInId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
                   request.auth.uid == request.resource.data.userId &&
                   request.resource.data.keys().hasAll(['userId', 'eventId', 'timestamp']) &&
                   request.resource.data.timestamp is timestamp;
      allow update: if isAuthenticated() && 
                   request.auth.uid == resource.data.userId;
      allow delete: if isAuthenticated() && 
                   request.auth.uid == resource.data.userId;
    }
    
    // Conversations - participants only
    match /conversations/{conversationId} {
      allow read, write: if isAuthenticated() &&
                        request.auth.uid in resource.data.participantIds;
      
      match /messages/{messageId} {
        allow read, write: if isAuthenticated() &&
                          request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantIds;
      }
    }
  }
}
```

### 10.3 Database Indexing Strategy

**Current Issue**: Some queries might be slow due to missing indexes.

**Proposed Solution**: Comprehensive indexing
```json
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "city", "order": "ASCENDING" },
        { "fieldPath": "age", "order": "ASCENDING" },
        { "fieldPath": "attractedTo", "order": "ASCENDING" },
        { "fieldPath": "isActive", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "city", "order": "ASCENDING" },
        { "fieldPath": "eventDate", "order": "ASCENDING" },
        { "fieldPath": "popularityScore", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "checkIns",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "eventId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "messages",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "conversationId", "order": "ASCENDING" },
        { "fieldPath": "timestamp", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

---

## 11. DevOps & CI/CD

### 11.1 Automated Testing Pipeline

**Current Issue**: No automated testing or CI/CD pipeline.

**Proposed Solution**: GitHub Actions workflow
```yaml
# .github/workflows/ios.yml
name: iOS CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    
    - name: Cache SPM dependencies
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
    
    - name: Build and Test
      run: |
        xcodebuild test \
          -project shift.xcodeproj \
          -scheme shift \
          -destination 'platform=iOS Simulator,name=iPhone 14,OS=latest' \
          -enableCodeCoverage YES \
          -derivedDataPath DerivedData
    
    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: DerivedData/Build/ProfileData/coverage.profdata
        
    - name: Run SwiftLint
      run: |
        if which swiftlint >/dev/null; then
          swiftlint
        else
          echo "SwiftLint not installed"
        fi

  firebase-deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        cache: 'npm'
        cache-dependency-path: functions/package-lock.json
    
    - name: Install Firebase CLI
      run: npm install -g firebase-tools
    
    - name: Install Functions dependencies
      run: cd functions && npm ci
    
    - name: Deploy to Firebase
      run: firebase deploy --token ${{ secrets.FIREBASE_TOKEN }}
```

### 11.2 Code Quality Tools

**Current Issue**: No automated code quality checks.

**Proposed Solution**: SwiftLint configuration
```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - closure_spacing
  - conditional_returns_on_newline
  - explicit_init
  - first_where
  - joined_default_parameter
  - operator_usage_whitespace
  - overridden_super_call
  - private_outlet
  - redundant_nil_coalescing
  - sorted_first_last
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call

included:
  - shift/

excluded:
  - Carthage
  - Pods
  - DerivedData

line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 500
  error: 1000

cyclomatic_complexity:
  warning: 10
  error: 20

nesting:
  type_level:
    warning: 2
    error: 3
  statement_level:
    warning: 5
    error: 10
```

---

## 12. Implementation Priority & Timeline

### Phase 1: Foundation (Weeks 1-3)
**High Priority - Core Architecture**
1. ✅ Implement MVVM architecture with ViewModels
2. ✅ Create dependency injection container
3. ✅ Set up comprehensive error handling
4. ✅ Implement structured logging system
5. ✅ Create input validation framework

### Phase 2: Performance & UX (Weeks 4-6)
**High Priority - User Experience**
1. ✅ Implement image caching system
2. ✅ Add lazy loading and pagination
3. ✅ Create reusable UI components
4. ✅ Implement offline data support with Core Data
5. ✅ Add comprehensive accessibility support

### Phase 3: Testing & Quality (Weeks 7-9)
**Medium Priority - Code Quality**
1. ✅ Set up unit testing framework
2. ✅ Implement UI testing suite
3. ✅ Configure CI/CD pipeline
4. ✅ Add code quality tools (SwiftLint)
5. ✅ Implement performance monitoring

### Phase 4: Features & Polish (Weeks 10-12)
**Medium Priority - Enhanced Features**
1. ✅ Add internationalization support
2. ✅ Implement advanced analytics
3. ✅ Enhance Firebase security rules
4. ✅ Optimize Cloud Functions
5. ✅ Add monitoring and alerting

### Phase 5: Security & Production (Weeks 13-15)
**High Priority - Production Readiness**
1. ✅ Implement keychain integration
2. ✅ Add comprehensive input sanitization
3. ✅ Security audit and penetration testing
4. ✅ Performance optimization review
5. ✅ Production deployment preparation

---

## 13. Success Metrics

### Technical Metrics
- **Code Coverage**: Target 80%+ unit test coverage
- **Performance**: App launch time < 2 seconds
- **Memory Usage**: Reduce memory footprint by 30%
- **Crash Rate**: Maintain < 0.1% crash rate
- **API Response Time**: < 500ms for member queries

### User Experience Metrics
- **Accessibility Score**: 100% VoiceOver compatibility
- **Load Times**: Image loading < 1 second
- **Offline Support**: Full offline member browsing
- **Localization**: Support for Spanish (Austin's 2nd most common language)

### Code Quality Metrics
- **Cyclomatic Complexity**: Average < 5 per function
- **File Size**: No files > 500 lines
- **Dependency Count**: Minimize external dependencies
- **SwiftLint Warnings**: Zero warnings in production builds

---

## 14. Risk Assessment

### High Risk
- **Migration Impact**: Changes to data models could break existing functionality
- **Firebase Costs**: Increased database queries could raise costs
- **Timeline**: Comprehensive refactoring might delay new features

### Medium Risk
- **User Experience**: Major UI changes might confuse existing users
- **Performance**: New architecture might initially be slower
- **Testing**: Extensive testing required to ensure stability

### Low Risk
- **Code Organization**: Internal restructuring shouldn't affect users
- **Logging**: Enhanced logging is purely additive
- **Accessibility**: Accessibility improvements are backward compatible

### Mitigation Strategies
1. **Feature Flags**: Implement gradual rollout of new features
2. **A/B Testing**: Test major UI changes with subset of users
3. **Staging Environment**: Full testing environment matching production
4. **Rollback Plan**: Ability to quickly revert problematic changes
5. **Monitoring**: Real-time alerting for performance regressions

---

## 15. Conclusion

This comprehensive refactoring plan addresses the major areas for improvement in the Shift app while maintaining the existing functionality and user experience. The plan follows industry best practices for iOS development, Firebase integration, and mobile app architecture.

**Key Benefits of Implementation:**
- **Maintainability**: Cleaner code organization and separation of concerns
- **Scalability**: Architecture that can handle growth to millions of users
- **Performance**: Faster load times and smoother user experience
- **Quality**: Comprehensive testing and error handling
- **Accessibility**: Support for all users including those with disabilities
- **Security**: Enhanced data protection and input validation
- **Internationalization**: Ready for global expansion

**Success Indicators:**
- Faster development of new features
- Reduced bug reports and crashes
- Improved user satisfaction scores
- Better App Store ratings
- Increased user retention and engagement

The refactoring should be implemented incrementally, with careful testing at each phase to ensure stability and performance. The architecture improvements will position the Shift app for long-term success and scalability in the competitive dating app market.