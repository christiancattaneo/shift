import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // Published properties
    @Published var subscriptions: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Product IDs
    private let productIds = [
        "com.christiancattaneo.shift.premium.monthly",
        "com.christiancattaneo.shift.premium.annual"
    ]
    
    // Transaction listener
    private var updateListenerTask: Task<Void, Error>? = nil
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expirationDate: Date?)
        case expired
        
        var isActive: Bool {
            switch self {
            case .subscribed:
                return true
            default:
                return false
            }
        }
    }
    
    private init() {
        // Start transaction listener
        updateListenerTask = listenForTransactions()
        
        // Load products and check subscription status
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Load Products
    
    func loadProducts() async {
        do {
            isLoading = true
            errorMessage = nil
            
            // Request products from the App Store
            let products = try await Product.products(for: productIds)
            
            // Sort by price (monthly first)
            self.subscriptions = products.sorted { $0.price < $1.price }
            
            print("📦 Loaded \(products.count) subscription products")
            
            isLoading = false
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load subscription options"
            isLoading = false
        }
    }
    
    // MARK: - Purchase Subscription
    
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        do {
            // Initiate purchase
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check whether the transaction is verified
                let transaction = try checkVerified(verification)
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Update user's subscription status in Firebase
                await updateFirebaseSubscriptionStatus(true)
                
                // Always finish a transaction
                await transaction.finish()
                
                isLoading = false
                return transaction
                
            case .userCancelled:
                print("👤 User cancelled purchase")
                isLoading = false
                return nil
                
            case .pending:
                print("⏳ Purchase pending")
                errorMessage = "Purchase is pending approval"
                isLoading = false
                return nil
                
            @unknown default:
                print("❓ Unknown purchase result")
                isLoading = false
                return nil
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // This will trigger the transaction listener for all past transactions
            try await AppStore.sync()
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            if subscriptionStatus.isActive {
                print("✅ Purchases restored successfully")
            } else {
                errorMessage = "No active subscriptions found"
            }
            
            isLoading = false
        } catch {
            print("❌ Restore failed: \(error)")
            errorMessage = "Failed to restore purchases"
            isLoading = false
        }
    }
    
    // MARK: - Check Subscription Status
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var latestExpirationDate: Date?
        
        // Check all product IDs for active subscriptions
        for productId in productIds {
            guard let status = await StoreKit.Transaction.currentEntitlement(for: productId) else {
                continue
            }
            
            do {
                let transaction = try checkVerified(status)
                
                if let expirationDate = transaction.expirationDate,
                   expirationDate > Date() {
                    hasActiveSubscription = true
                    
                    // Keep track of the latest expiration date
                    if latestExpirationDate == nil || expirationDate > latestExpirationDate! {
                        latestExpirationDate = expirationDate
                    }
                }
            } catch {
                print("❌ Error checking subscription status: \(error)")
            }
        }
        
        // Update status
        if hasActiveSubscription {
            subscriptionStatus = .subscribed(expirationDate: latestExpirationDate)
            await updateFirebaseSubscriptionStatus(true)
        } else if latestExpirationDate != nil {
            subscriptionStatus = .expired
            await updateFirebaseSubscriptionStatus(false)
        } else {
            subscriptionStatus = .notSubscribed
            await updateFirebaseSubscriptionStatus(false)
        }
        
        print("📊 Subscription status: \(subscriptionStatus)")
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transactions
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Update subscription status
                    await self.updateSubscriptionStatus()
                    
                    // Always finish transactions
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verify Transaction
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Firebase Integration
    
    nonisolated private func updateFirebaseSubscriptionStatus(_ isSubscribed: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            
            // Create the update data on the main actor to avoid sendability issues
            let updateData: [String: Any] = [
                "subscribed": isSubscribed,
                "subscriptionUpdatedAt": FieldValue.serverTimestamp()
            ]
            
            // Update user document
            try await db.collection("users").document(userId).updateData(updateData)
            
            print("✅ Updated Firebase subscription status: \(isSubscribed)")
        } catch {
            print("❌ Failed to update Firebase subscription status: \(error)")
        }
    }
    
    // MARK: - Helpers
    
    func priceString(for product: Product) -> String {
        product.displayPrice
    }
    
    func periodString(for product: Product) -> String {
        switch product.subscription?.subscriptionPeriod.unit {
        case .month:
            return "month"
        case .year:
            return "year"
        default:
            return ""
        }
    }
    
    var isSubscribed: Bool {
        subscriptionStatus.isActive
    }
}

// MARK: - Error Types

enum SubscriptionError: LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        case .purchaseFailed:
            return "Purchase could not be completed"
        case .productNotFound:
            return "Product not found"
        }
    }
} 