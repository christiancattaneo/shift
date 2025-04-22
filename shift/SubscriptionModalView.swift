import SwiftUI

struct SubscriptionModalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Top Logo 
            HStack {
                Image("shiftlogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                Text("Shift")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)

            // Modal Content Box
            VStack(alignment: .center, spacing: 20) {
                // Header with Close button
                HStack {
                    Text("Monthly Subscription")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            // Use gray for better visibility in light mode
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 5)

                // Use standard adaptive divider
                Divider()

                Text("Subscribe to see singles where you\'re at & plan to be")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)

                Text("$5 Monthly Subscription")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Credit Card Input Placeholder
                VStack(alignment: .leading, spacing: 4) {
                    Text("Credit or debit card")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    // --- Placeholder --- 
                    RoundedRectangle(cornerRadius: 8)
                        // Use systemGray6 for better visibility in light mode
                        .fill(colorScheme == .dark ? Color(white: 0.25) : Color(.systemGray6)) // Darker gray for dark mode too
                        .frame(height: 45)
                    // --- End Placeholder ---
                }
                .padding(.vertical, 10)


                // Subscribe Button
                Button {
                    // TODO: Implement subscription logic
                    print("Subscribe Tapped")
                    dismiss()
                } label: {
                    Text("+ SUBSCRIBE")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        // Use standard system purple
                        .background(Color.purple) 
                        .cornerRadius(10)
                }

                Text("Subscription can be canceled anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Charge monthly on 27th") // TODO: Make this dynamic
                    .font(.caption)
                    .foregroundColor(.secondary)

            }
            .padding(25)
            // Conditional background for the modal box
            .background(colorScheme == .dark ? Color(white: 0.15) : Color(.systemBackground))
            .cornerRadius(20)
            // Shadows adapt automatically to some extent
            .shadow(radius: 10)
            .padding(.horizontal, 20) 

            Spacer() 
        }
        // .background(.clear) // Let the sheet manage the dimming 
        // Instead of ZStack + Spacer, apply background directly to VStack
        // .frame(maxHeight: .infinity) // Allow VStack to expand
        // .background(Color(.systemBackground).opacity(0.001)) // Capture taps if needed
    }
}

#Preview {
    // Preview in both light and dark modes
    Group {
        // Wrap previews in a ZStack with a non-white background 
        // to better see the modal's background color
        ZStack {
            Color.gray.opacity(0.3).ignoresSafeArea()
            SubscriptionModalView()
        }
        .preferredColorScheme(.dark)
        
        ZStack {
            Color.gray.opacity(0.3).ignoresSafeArea()
            SubscriptionModalView()
        }
        .preferredColorScheme(.light)
    }
} 