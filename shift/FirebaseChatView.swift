import SwiftUI

// Firebase Chat View for real-time messaging
struct FirebaseChatView: View {
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
                TextField("Type a message...", text: $newMessageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                
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
            if let conversationId = conversation.id {
                messagesService.fetchMessages(for: conversationId)
            }
        }
    }
    
    private func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let conversationId = conversation.id else { return }
        
        let messageText = newMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messagesService.sendMessage(
            conversationId: conversationId,
            senderId: userId,
            messageText: messageText
        ) { success, error in
            if !success {
                print("Failed to send message: \(error ?? "Unknown error")")
            }
        }
        newMessageText = ""
    }
    
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        FirebaseChatView(
            conversation: FirebaseConversation(
                participantOneId: "user1",
                participantTwoId: "user2",
                lastMessage: "Hello!"
            ),
            participantName: "John Doe",
            participantImageURL: nil
        )
    }
} 