import SwiftUI

struct MainTabView: View {
    // State to control the modal presentation
    @State private var showSubscriptionModal: Bool
    
    // Accept initial state from parent view
    init(showSubscriptionModalInitially: Bool = false) {
        _showSubscriptionModal = State(initialValue: showSubscriptionModalInitially)
    }

    var body: some View {
        TabView {
            MembersView()
                .tabItem {
                    Label("Members", systemImage: "person.2.fill")
                }

            // Replace Placeholder with actual CheckInsView
            CheckInsView()
                .tabItem {
                    Label("Check-Ins", systemImage: "mappin.and.ellipse")
                }

            // Replace Placeholder with actual ConversationsListView
            ConversationsListView()
                .tabItem {
                    Label("Message", systemImage: "message.fill")
                }

            // Replace Placeholder with actual ProfileView
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
            
            // Removed Adalo test tab after migration to Firebase
        }
        // Use accent color for the selected tab item
        .accentColor(.blue)
        // Present the subscription modal when the state variable is true
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionModalView()
                .presentationBackground(.clear)
                // Prevent interactive dismissal if needed, force user action in modal
                // .interactiveDismissDisabled()
        }
        // Optional: Set background for TabView bar if needed
        // .onAppear {
        //     UITabBar.appearance().backgroundColor = UIColor.systemBackground
        // }
    }
}

#Preview {
    MainTabView()
}

#Preview("Show Modal Initially") {
    MainTabView(showSubscriptionModalInitially: true)
} 