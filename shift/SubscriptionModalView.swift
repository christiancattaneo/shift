import SwiftUI

struct SubscriptionModalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan = "monthly"
    @State private var isAnimating = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showError = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Features Section
                    featuresSection
                    
                    // Pricing Section
                    pricingSection
                    
                    // Payment Section
                    paymentSection
                    
                    // Subscribe Button
                    subscribeButton
                    
                    // Footer
                    footerSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .alert("Subscription Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(subscriptionManager.errorMessage ?? "Unable to complete purchase. Please try again.")
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Close Button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Logo & Title
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Shift Premium")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Unlock Your Dating Potential")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            Text("Premium Features")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 32)
            
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "location.fill",
                    title: "Location Discovery",
                    description: "See singles where you are and where you're planning to be",
                    iconColor: .blue
                )
                
                FeatureRow(
                    icon: "eye.fill",
                    title: "See Who Viewed You",
                    description: "Get insights into who's checking out your profile",
                    iconColor: .green
                )
                
                FeatureRow(
                    icon: "heart.fill",
                    title: "Unlimited Likes",
                    description: "Like as many profiles as you want without restrictions",
                    iconColor: .red
                )
                
                FeatureRow(
                    icon: "message.fill",
                    title: "Priority Messages",
                    description: "Your messages get delivered first and highlighted",
                    iconColor: .orange
                )
                
                FeatureRow(
                    icon: "star.fill",
                    title: "Profile Boost",
                    description: "Get 10x more profile views with our boost feature",
                    iconColor: .yellow
                )
            }
        }
        .padding(.vertical, 24)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 20) {
            Text("Choose Your Plan")
                .font(.title2)
                .fontWeight(.semibold)
            
            if subscriptionManager.isLoading {
                ProgressView("Loading subscription options...")
                    .padding()
            } else if subscriptionManager.subscriptions.isEmpty {
                Text("Unable to load subscription options")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(subscriptionManager.subscriptions, id: \.id) { product in
                        let isMonthly = product.id.contains("monthly")
                        let isSelected = (isMonthly && selectedPlan == "monthly") || (!isMonthly && selectedPlan == "annual")
                        
                        PricingCard(
                            title: isMonthly ? "Monthly" : "Annual",
                            price: product.displayPrice,
                            originalPrice: isMonthly ? nil : "$239.88",
                            period: isMonthly ? "per month" : "per year",
                            features: isMonthly ? 
                                ["All premium features", "Cancel anytime"] : 
                                ["All premium features", "Save $40 per year", "Best value"],
                            isSelected: isSelected,
                            isPopular: !isMonthly
                        ) {
                            selectedPlan = isMonthly ? "monthly" : "annual"
                            Haptics.lightImpact()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    private var paymentSection: some View {
        VStack(spacing: 16) {
            Text("Payment Method")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Credit Card Input Placeholder
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("Credit or Debit Card")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(white: 0.15) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Security Notice
                HStack(spacing: 8) {
                    Image(systemName: "shield.checkered")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text("Your payment information is secure and encrypted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    private var subscribeButton: some View {
        VStack(spacing: 12) {
            Button(action: handleSubscription) {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.headline)
                    Text("Start Premium - \(selectedPlan == "monthly" ? "$5.99/month" : "$4.99/month")")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Trial info
            if selectedPlan == "monthly" {
                Text("3-day free trial, then $5.99/month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("3-day free trial, then $59.99/year")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Subscription Details")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                Text("• Cancel anytime from your account settings")
                Text("• Auto-renewal can be turned off anytime")
                Text("• Charges occur monthly on the 27th")
                Text("• Full access to all premium features immediately")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .padding(.vertical, 8)
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    showTermsOfService = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Privacy Policy") {
                    showPrivacyPolicy = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Restore Purchase") {
                    Task {
                        await subscriptionManager.restorePurchases()
                        if subscriptionManager.subscriptionStatus.isActive {
                            dismiss()
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Helper Functions
    
    private func handleSubscription() {
        Task {
            // Find the selected product
            guard let product = subscriptionManager.subscriptions.first(where: { product in
                if selectedPlan == "monthly" {
                    return product.id.contains("monthly")
                } else {
                    return product.id.contains("annual")
                }
            }) else {
                print("❌ Product not found for plan: \(selectedPlan)")
                return
            }
            
            do {
                // Attempt purchase
                if try await subscriptionManager.purchase(product) != nil {
                    Haptics.successNotification()
                    dismiss()
                }
            } catch {
                print("❌ Purchase failed: \(error)")
                Haptics.errorNotification()
                showError = true
            }
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(iconColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct PricingCard: View {
    let title: String
    let price: String
    let originalPrice: String?
    let period: String
    let features: [String]
    let isSelected: Bool
    let isPopular: Bool
    let action: () -> Void
    
    init(
        title: String,
        price: String,
        originalPrice: String? = nil,
        period: String,
        features: [String],
        isSelected: Bool,
        isPopular: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.price = price
        self.originalPrice = originalPrice
        self.period = period
        self.features = features
        self.isSelected = isSelected
        self.isPopular = isPopular
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(price)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if let originalPrice = originalPrice {
                                Text(originalPrice)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                            }
                            
                            Text(period)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if isPopular {
                        Text("BEST VALUE")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text(feature)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.blue : (isPopular ? Color.orange.opacity(0.5) : Color(.systemGray4)),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? .blue.opacity(0.2) : .black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    Group {
        SubscriptionModalView()
            .preferredColorScheme(.light)
        
        SubscriptionModalView()
            .preferredColorScheme(.dark)
    }
} 