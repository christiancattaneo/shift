import SwiftUI
import FirebaseAuth

// MARK: - Error Types

enum AppError: LocalizedError {
    case networkError
    case authenticationError(String)
    case dataLoadingError(String)
    case locationError(String)
    case subscriptionError(String)
    case genericError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network Error"
        case .authenticationError:
            return "Authentication Error"
        case .dataLoadingError:
            return "Loading Error"
        case .locationError:
            return "Location Error"
        case .subscriptionError:
            return "Subscription Error"
        case .genericError:
            return "Error"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .networkError:
            return "Unable to connect to the internet. Please check your connection and try again."
        case .authenticationError(let message):
            return message
        case .dataLoadingError(let message):
            return message
        case .locationError(let message):
            return message
        case .subscriptionError(let message):
            return message
        case .genericError(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection"
        case .authenticationError:
            return "Try signing in again"
        case .dataLoadingError:
            return "Pull to refresh"
        case .locationError:
            return "Check location permissions in Settings"
        case .subscriptionError:
            return "Check your subscription status"
        case .genericError:
            return "Please try again"
        }
    }
}

// MARK: - Error Handler

@MainActor
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var showError = false
    @Published var isRetrying = false
    
    private var retryAction: (() async -> Void)?
    
    private init() {}
    
    // MARK: - Show Error
    
    func show(_ error: AppError, retryAction: (() async -> Void)? = nil) {
        Haptics.errorNotification()
        self.currentError = error
        self.retryAction = retryAction
        self.showError = true
        
        print("❌ Error shown: \(error.errorDescription ?? "Unknown") - \(error.failureReason ?? "")")
    }
    
    func show(_ error: Error, retryAction: (() async -> Void)? = nil) {
        // Convert Firebase or system errors to AppError
        let appError = convertToAppError(error)
        show(appError, retryAction: retryAction)
    }
    
    // MARK: - Retry
    
    func retry() async {
        guard let retryAction = retryAction else { return }
        
        isRetrying = true
        showError = false
        
        await retryAction()
        
        isRetrying = false
    }
    
    func dismiss() {
        showError = false
        currentError = nil
        retryAction = nil
    }
    
    // MARK: - Error Conversion
    
    private func convertToAppError(_ error: Error) -> AppError {
        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError
            default:
                return .dataLoadingError("Unable to load data. \(urlError.localizedDescription)")
            }
        }
        
        // Check for Firebase Auth errors
        if let authError = error as? AuthErrorCode {
            switch authError.code {
            case .networkError:
                return .networkError
            case .userNotFound:
                return .authenticationError("No account found with this email.")
            case .wrongPassword:
                return .authenticationError("Incorrect password.")
            case .invalidEmail:
                return .authenticationError("Invalid email address.")
            case .emailAlreadyInUse:
                return .authenticationError("This email is already registered.")
            case .weakPassword:
                return .authenticationError("Password is too weak.")
            case .tooManyRequests:
                return .authenticationError("Too many attempts. Please try again later.")
            default:
                return .authenticationError("Authentication failed. Please try again.")
            }
        }
        
        // Generic error
        return .genericError(error.localizedDescription)
    }
}

// MARK: - Error Alert View Modifier

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject private var errorHandler = ErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorHandler.currentError?.errorDescription ?? "Error",
                isPresented: $errorHandler.showError
            ) {
                Button("Dismiss") {
                    errorHandler.dismiss()
                }
                
                if errorHandler.retryAction != nil {
                    Button("Retry") {
                        Task {
                            await errorHandler.retry()
                        }
                    }
                }
            } message: {
                VStack {
                    if let reason = errorHandler.currentError?.failureReason {
                        Text(reason)
                    }
                    if let suggestion = errorHandler.currentError?.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
            .overlay {
                if errorHandler.isRetrying {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Retrying...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                }
            }
    }
}

extension View {
    func errorAlert() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(32)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if let buttonTitle = buttonTitle, let action = action {
                Button(action: action) {
                    Text(buttonTitle)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(25)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 