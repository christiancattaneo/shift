import SwiftUI

// Placeholder data structure for a conversation
struct Conversation: Identifiable {
    let id = UUID()
    let recipientName: String
    let lastMessage: String
    let timestamp: String // Simple string for now
    let profileImageName: String? // System name or asset
    var isRead: Bool = false
}

struct ConversationsListView: View {
    
    // Sample Data - Replace with actual data source later
    @State private var conversations: [Conversation] = [
        Conversation(recipientName: "Caroline", lastMessage: "Sounds good! See you there.", timestamp: "10:35 AM", profileImageName: "person.crop.circle.fill", isRead: false),
        Conversation(recipientName: "Omeed", lastMessage: "Haha, maybe next time.", timestamp: "Yesterday", profileImageName: "person.crop.circle.fill", isRead: true),
        Conversation(recipientName: "Macey", lastMessage: "Okay perfect!", timestamp: "Tuesday", profileImageName: "person.crop.circle.fill", isRead: false),
        Conversation(recipientName: "Marin", lastMessage: "Got it, thanks!", timestamp: "Monday", profileImageName: "person.crop.circle.fill", isRead: true)
    ]
    
    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView { // Provide navigation context for potential detail views
            List {
                ForEach(conversations) { conversation in
                    NavigationLink(destination: ChatDetailView(conversation: conversation)) { // Link to chat detail
                        ConversationRow(conversation: conversation)
                    }
                    // Add swipe actions if desired later
                    // .swipeActions(edge: .trailing) { ... }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
            // Add search bar if desired
            // .searchable(text: $searchText)
            .toolbar {
                // Optional: Add button for new message
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // TODO: Action to start new message
                        print("New Message Tapped")
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
        .accentColor(.blue) // Consistent accent color
    }
}

// Row view for each conversation
struct ConversationRow: View {
    let conversation: Conversation
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            // Profile Image Placeholder
            Image(systemName: conversation.profileImageName ?? "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 55, height: 55)
                .clipShape(Circle())
                .foregroundColor(.gray)
                // Optional: Add online indicator
                // .overlay(Circle().fill(Color.green).frame(width: 15, height: 15).offset(x: 20, y: 20))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.recipientName)
                        .font(.headline)
                        // Bold if unread
                        .fontWeight(conversation.isRead ? .regular : .semibold)
                    Spacer()
                    Text(conversation.timestamp)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(conversation.isRead ? .secondary : .primary)
                    .lineLimit(1) // Show only one line
            }
            
            // Optional: Unread indicator dot
            if !conversation.isRead {
                 Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
    }
}

// Placeholder for the actual chat screen
struct ChatDetailView: View {
    let conversation: Conversation
    
    var body: some View {
        Text("Chat with \(conversation.recipientName)")
            .navigationTitle(conversation.recipientName)
            .navigationBarTitleDisplayMode(.inline)
    }
}


#Preview {
    ConversationsListView()
} 