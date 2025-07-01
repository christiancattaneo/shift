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
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @Environment(\.colorScheme) var colorScheme
    
    var filteredConversations: [FirebaseConversation] {
        if searchText.isEmpty {
            return conversationsService.conversations
        } else {
            return conversationsService.conversations.filter { conversation in
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
                // Header Section
                headerSection
                
                // Content Section
                if conversationsService.isLoading {
                    loadingSection
                } else if filteredConversations.isEmpty {
                    emptyStateSection
                } else {
                    conversationsListSection
                }
                
                // Error Handling
                errorSection
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewMessage = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .refreshable {
                await refreshConversations()
            }
        }
        .sheet(isPresented: $showingNewMessage) {
            NewMessageRecipientView(members: membersService.members) { selectedMember in
                handleNewConversation(with: selectedMember)
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Active Conversations Counter
            if !filteredConversations.isEmpty {
                HStack {
                    Text("\(filteredConversations.count) conversations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading conversations...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No conversations yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start connecting with other members by sending them a message")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Start Conversation") {
                showingNewMessage = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var conversationsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredConversations) { conversation in
                    NavigationLink(
                        destination: FirebaseChatView(
                            conversation: conversation,
                            participantName: getParticipantName(for: conversation),
                            participantImageURL: getParticipantImageURL(for: conversation)
                        )
                    ) {
                        EnhancedConversationCard(
                            conversation: conversation,
                            participantName: getParticipantName(for: conversation),
                            participantImageURL: getParticipantImageURL(for: conversation)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private var errorSection: some View {
        Group {
            if let errorMessage = conversationsService.errorMessage {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Connection Error")
                            .font(.headline)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Button("Retry") {
                        if let currentUser = FirebaseUserSession.shared.currentUser,
                           let userId = currentUser.id {
                            conversationsService.fetchConversations(for: userId)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: conversationsService.errorMessage)
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        if let currentUser = FirebaseUserSession.shared.currentUser,
           let userId = currentUser.id {
            conversationsService.fetchConversations(for: userId)
        }
        membersService.fetchMembers()
    }
    
    private func refreshConversations() async {
        if let currentUser = FirebaseUserSession.shared.currentUser,
           let userId = currentUser.id {
            conversationsService.fetchConversations(for: userId)
        }
        membersService.fetchMembers()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func handleNewConversation(with selectedMember: FirebaseMember) {
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

// MARK: - Enhanced Conversation Card

struct EnhancedConversationCard: View {
    let conversation: FirebaseConversation
    let participantName: String
    let participantImageURL: URL?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Profile Image
            AsyncImage(url: participantImageURL) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                        )
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                case .failure(_):
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(participantName.prefix(1).uppercased())
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        )
                @unknown default:
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                }
            }

            // Conversation Details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(participantName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(formatTimestamp(lastMessageAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(conversation.lastMessage ?? "No messages yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Unread indicator
                    if conversation.isRead == false {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(conversation.isRead == false ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    private func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.setLocalizedDateFormatFromTemplate("EEEE")
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    ConversationsListView()
}