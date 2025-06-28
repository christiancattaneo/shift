import SwiftUI
import Combine
import FirebaseFirestore

// Placeholder data structure for a User
struct User: Identifiable, Hashable { // Hashable needed for NavigationLink value
    let id = UUID()
    let name: String
    let profileImageName: String?
}

// Sample Users (potential recipients)
let sampleUsers: [User] = [
    User(name: "Caroline", profileImageName: "person.crop.circle.fill"),
    User(name: "Omeed", profileImageName: "person.crop.circle.fill"),
    User(name: "Macey", profileImageName: "person.crop.circle.fill"),
    User(name: "Marin", profileImageName: "person.crop.circle.fill"),
    User(name: "Alex", profileImageName: "person.crop.circle.fill.badge.plus"), // Different icon for variety
    User(name: "Sam", profileImageName: "person.crop.circle.fill")
]

// Placeholder data structure for a single message
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isSender: Bool // True if the current user sent it
    let timestamp: Date // Use Date for proper sorting/display
}

// Placeholder data structure for a conversation
struct Conversation: Identifiable {
    let id = UUID()
    let recipientName: String
    let lastMessage: String
    let timestamp: String // Simple string for now
    let profileImageName: String? // System name or asset
    var isRead: Bool = false
    // Add sample messages for the conversation
    var messages: [Message] = []
}

struct ConversationsListView: View {
    @State private var searchText = ""
    @State private var showingNewMessage = false
    @StateObject private var conversationsService = FirebaseConversationsService()
    @StateObject private var membersService = FirebaseMembersService()
    @Environment(\.colorScheme) var colorScheme
    
    var filteredConversations: [FirebaseConversation] {
        if searchText.isEmpty {
            return conversationsService.conversations
        } else {
            return conversationsService.conversations.filter { conversation in
                // Filter based on last message or participant info
                conversation.lastMessage?.localizedCaseInsensitiveContains(searchText) ?? false ||
                getParticipantName(for: conversation).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // Helper function to get participant name
    func getParticipantName(for conversation: FirebaseConversation) -> String {
        guard let currentUser = FirebaseUserSession.shared.currentUser else { return "Unknown" }
        
        let otherParticipantId = conversation.participantOneId == currentUser.id ? 
            conversation.participantTwoId : conversation.participantOneId
            
        if let otherParticipantId = otherParticipantId,
           let member = membersService.members.first(where: { $0.id == otherParticipantId }) {
            return member.firstName
        }
        
        return "User \(otherParticipantId ?? "")"
    }
    
    // Helper function to get participant profile image
    func getParticipantImageURL(for conversation: FirebaseConversation) -> URL? {
        guard let currentUser = FirebaseUserSession.shared.currentUser else { return nil }
        
        let otherParticipantId = conversation.participantOneId == currentUser.id ? 
            conversation.participantTwoId : conversation.participantOneId
            
        if let otherParticipantId = otherParticipantId,
           let member = membersService.members.first(where: { $0.id == otherParticipantId }) {
            return member.profileImageURL
        }
        
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 15) {
                    HStack {
                        Text("Messages")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        
                        // New Message Button
                        Button(action: {
                            showingNewMessage = true
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search conversations", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Conversations List
                if conversationsService.isLoading {
                    Spacer()
                    VStack {
                        ProgressView("Loading conversations...")
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Fetching your messages...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                    Spacer()
                } else if filteredConversations.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "message")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No conversations yet")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Start a conversation with someone!")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("New Message") {
                            showingNewMessage = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    Spacer()
                } else {
                    List {
                        ForEach(filteredConversations) { conversation in
                            NavigationLink(
                                destination: FirebaseChatView(
                                    conversation: conversation,
                                    participantName: getParticipantName(for: conversation),
                                    participantImageURL: getParticipantImageURL(for: conversation)
                                )
                            ) {
                                ConversationRow(
                                    conversation: conversation,
                                    participantName: getParticipantName(for: conversation),
                                    participantImageURL: getParticipantImageURL(for: conversation)
                                )
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    // Data source indicator
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Real conversations from Firebase • \(filteredConversations.count) chats")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                
                // Error handling
                if let errorMessage = conversationsService.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Connection Error")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Button("Retry") {
                            if let currentUser = FirebaseUserSession.shared.currentUser,
                               let userId = currentUser.id {
                                conversationsService.fetchConversations(for: userId)
                            }
                        }
                        .padding(.top, 5)
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
        }
        .sheet(isPresented: $showingNewMessage) {
            NewMessageRecipientView(
                members: membersService.members
            ) { selectedMember in
                // Handle new conversation creation
                if let currentUser = FirebaseUserSession.shared.currentUser,
                   let userId = currentUser.id,
                   let participantTwoId = selectedMember.id {
                        conversationsService.createConversation(
                            participantOneId: userId,
                            participantTwoId: participantTwoId,
                            completion: { success, error in
                                if !success {
                                    print("Failed to create conversation: \(error ?? "Unknown error")")
                                }
                            }
                        )
                }
            }
        }
        .onAppear {
            if let currentUser = FirebaseUserSession.shared.currentUser,
               let userId = currentUser.id {
                conversationsService.fetchConversations(for: userId)
            }
            membersService.fetchMembers()
        }
        .refreshable {
            if let currentUser = FirebaseUserSession.shared.currentUser,
               let userId = currentUser.id {
                conversationsService.fetchConversations(for: userId)
            }
            membersService.fetchMembers()
        }
    }
}

// Row view for each conversation
struct ConversationRow: View {
    let conversation: FirebaseConversation
    let participantName: String
    let participantImageURL: URL?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 15) {
            // Profile Image
            AsyncImage(url: participantImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 55, height: 55)
                    .clipShape(Circle())
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 55, height: 55)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participantName)
                        .font(.headline)
                        .fontWeight(conversation.isRead == false ? .semibold : .regular)
                    Spacer()
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(formatTimestamp(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(conversation.lastMessage ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(conversation.isRead == false ? .primary : .secondary)
                    .lineLimit(1)
            }
            
            // Optional: Unread indicator dot
            if conversation.isRead == false {
                 Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
    }
    
    // Helper function to format timestamp
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        
        // Check if the date is today
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// Updated Chat screen to use real Firebase data
struct ChatView: View {
    let conversation: FirebaseConversation
    let participantName: String
    let participantImageURL: URL?
    @StateObject private var messagesService = FirebaseMessagesService()
    @State private var newMessageText = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                AsyncImage(url: participantImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 35, height: 35)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading) {
                    Text(participantName)
                        .font(.headline)
                    Text("Online")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Messages list
            if messagesService.isLoading {
                Spacer()
                ProgressView("Loading messages...")
                Spacer()
            } else if messagesService.messages.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "message")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No messages yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Start the conversation!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(messagesService.messages) { message in
                            HStack {
                                if message.isSender {
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(message.messageText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(18)
                                        Text(formatMessageTime(message.timestamp))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    VStack(alignment: .leading) {
                                        Text(message.messageText)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(18)
                                        Text(formatMessageTime(message.timestamp))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            
            // Message input
            HStack(spacing: 12) {
                CustomMessageInput(text: $newMessageText, placeholder: "Type a message...", maxHeight: 100)
                    .frame(minHeight: 44)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(newMessageText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(newMessageText.isEmpty)
            }
            .padding()
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            messagesService.fetchMessages(for: conversation.id ?? "")
        }
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = FirebaseUserSession.shared.currentUser else { return }
        
        let messageText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messagesService.sendMessage(
            conversationId: conversation.id ?? "",
            senderId: currentUser.id ?? "",
            messageText: messageText,
            completion: { success, error in
                if !success {
                    print("Failed to send message: \(error ?? "Unknown error")")
                }
            }
        )
        newMessageText = ""
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Make Conversation Hashable for NavigationLink value
extension Conversation: Hashable {
    // Implement hash(into:) and == based on conversation ID or recipient identity
    func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Use ID for hashing
    }
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id // Use ID for equality
    }
}

#Preview {
    ConversationsListView()
} 