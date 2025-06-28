import SwiftUI

struct MainTabView: View {
    // State to control the modal presentation
    @State private var showSubscriptionModal: Bool = false
    @State private var selectedTab: Int = 0
    
    // Accept initial state from parent view
    init(showSubscriptionModalInitially: Bool = false) {
        // Ensure modal state is properly initialized
        print("🎯 MainTabView init - modal should show: \(showSubscriptionModalInitially)")
        _showSubscriptionModal = State(initialValue: showSubscriptionModalInitially)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MembersView()
                    .onAppear {
                        print("👥 MembersView appeared")
                    }
            }
            .tabItem {
                Label("Members", systemImage: "person.2.fill")
            }
            .tag(0)

            NavigationStack {
                CheckInsView()
                    .onAppear {
                        print("📍 CheckInsView appeared")
                    }
            }
            .tabItem {
                Label("Check-Ins", systemImage: "mappin.and.ellipse")
            }
            .tag(1)

            NavigationStack {
                ConversationsListView()
                    .onAppear {
                        print("💬 ConversationsListView appeared")
                    }
            }
            .tabItem {
                Label("Message", systemImage: "message.fill")
            }
            .tag(2)

            NavigationStack {
                ProfileView()
                    .onAppear {
                        print("👤 ProfileView appeared")
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(3)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 Tab changed from \(oldValue) to \(newValue)")
        }
        .onAppear {
            print("🎯 MainTabView body appeared - modal state: \(showSubscriptionModal)")
        }
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionModalView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    MainTabView()
}

#Preview("Show Modal Initially") {
    MainTabView(showSubscriptionModalInitially: true)
} 