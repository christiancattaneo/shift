import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("Last Updated: January 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Introduction
                    Section {
                        Text("Welcome to Shift. We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our dating app.")
                            .font(.body)
                    }
                    
                    // Information We Collect
                    Section {
                        Text("Information We Collect")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• **Profile Information**: Name, age, gender, photos, and preferences")
                        Text("• **Location Data**: To show you singles nearby (only when you grant permission)")
                        Text("• **Usage Data**: How you interact with the app")
                        Text("• **Messages**: Communications between users")
                    }
                    
                    // How We Use Your Information
                    Section {
                        Text("How We Use Your Information")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("• To create and maintain your account")
                        Text("• To match you with compatible users")
                        Text("• To enable location-based features")
                        Text("• To improve our services")
                        Text("• To ensure safety and prevent fraud")
                    }
                    
                    // Data Sharing
                    Section {
                        Text("Data Sharing")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("We do not sell your personal data. We may share information:")
                        Text("• With other users (your public profile)")
                        Text("• With service providers (hosting, analytics)")
                        Text("• For legal compliance")
                        Text("• To protect safety")
                    }
                    
                    // Your Rights
                    Section {
                        Text("Your Rights")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("You have the right to:")
                        Text("• Access your personal data")
                        Text("• Update or correct your information")
                        Text("• Delete your account")
                        Text("• Control location permissions")
                        Text("• Opt-out of marketing communications")
                    }
                    
                    // Data Security
                    Section {
                        Text("Data Security")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("We implement industry-standard security measures to protect your data, including encryption and secure servers. However, no method is 100% secure.")
                    }
                    
                    // Contact Us
                    Section {
                        Text("Contact Us")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        Text("If you have questions about this privacy policy, please contact us at:")
                        Link("support@shiftdating.app", destination: URL(string: "mailto:support@shiftdating.app")!)
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
    PrivacyPolicyView()
} 