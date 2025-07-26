import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("Last Updated: January 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Agreement
                    Section {
                        Text("By using Shift, you agree to these Terms of Service. If you do not agree, please do not use our app.")
                            .font(.body)
                    }
                    
                    // Eligibility
                    Section {
                        Text("Eligibility")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• You must be at least 18 years old")
                        Text("• You must have the legal capacity to enter into a binding contract")
                        Text("• You are not prohibited from using the app under applicable laws")
                    }
                    
                    // Your Account
                    Section {
                        Text("Your Account")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• You are responsible for maintaining account security")
                        Text("• You must provide accurate information")
                        Text("• One person per account")
                        Text("• You are responsible for all activity under your account")
                    }
                    
                    // Content and Conduct
                    Section {
                        Text("Content and Conduct")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("You agree NOT to:")
                        Text("• Post inappropriate, offensive, or illegal content")
                        Text("• Harass, abuse, or harm other users")
                        Text("• Use the app for commercial solicitation")
                        Text("• Impersonate others or misrepresent yourself")
                        Text("• Violate any laws or third-party rights")
                    }
                    
                    // Safety
                    Section {
                        Text("Safety")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• You are solely responsible for your interactions")
                        Text("• Exercise caution when meeting in person")
                        Text("• Never send money or share financial information")
                        Text("• Report suspicious behavior immediately")
                    }
                    
                    // Premium Features
                    Section {
                        Text("Premium Features")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• Subscriptions auto-renew unless cancelled")
                        Text("• Prices may vary by location")
                        Text("• No refunds for unused periods")
                        Text("• You can manage subscriptions in your device settings")
                    }
                    
                    // Intellectual Property
                    Section {
                        Text("Intellectual Property")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• Shift owns all app content and features")
                        Text("• You retain rights to your content")
                        Text("• You grant us license to use your content")
                        Text("• Do not infringe on others' intellectual property")
                    }
                    
                    // Disclaimers
                    Section {
                        Text("Disclaimers")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• Service provided \"as is\" without warranties")
                        Text("• We do not guarantee finding matches")
                        Text("• We are not responsible for user behavior")
                        Text("• We may modify or discontinue features")
                    }
                    
                    // Limitation of Liability
                    Section {
                        Text("Limitation of Liability")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("To the fullest extent permitted by law, Shift shall not be liable for any indirect, incidental, special, consequential, or punitive damages.")
                    }
                    
                    // Termination
                    Section {
                        Text("Termination")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• We may terminate accounts for violations")
                        Text("• You may delete your account at any time")
                        Text("• Some provisions survive termination")
                    }
                    
                    // Contact
                    Section {
                        Text("Contact")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("For questions about these terms:")
                        Link("legal@shiftdating.app", destination: URL(string: "mailto:legal@shiftdating.app")!)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TermsOfServiceView()
} 