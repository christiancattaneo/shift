import SwiftUI

struct MainTabView: View {
    // State to control the modal presentation
    @State private var showSubscriptionModal: Bool = false
    @State private var selectedTab: Int = 0
    
    // Accept initial state from parent view
    init(showSubscriptionModalInitially: Bool = false) {
        // Ensure modal state is properly initialized
        print("🎯 MainTabView init - modal should show: \(showSubscriptionModalInitially)")
        print("🎯 MainTabView init: Thread=MAIN")
        _showSubscriptionModal = State(initialValue: showSubscriptionModalInitially)
    }

    var body: some View {
        // ENHANCED LOGGING: Track every body evaluation
        let _ = print("🎯 MainTabView body: selectedTab=\(selectedTab), showModal=\(showSubscriptionModal)")
        let _ = print("🎯 MainTabView body: Thread=MAIN")
        
        TabView(selection: $selectedTab) {
            NavigationStack {
                MembersView()
                    .onAppear {
                        print("👥 MembersView appeared")
                        print("👥 MembersView onAppear: Thread=MAIN")
                    }
                    .onTapGesture {
                        print("👥 MEMBERS VIEW TAPPED - UI should be responsive")
                    }
            }
            .tabItem {
                Label("Members", systemImage: "person.2.fill")
            }
            .tag(0)
            .onTapGesture {
                print("👥 MEMBERS TAB ITEM TAPPED - should switch to tab 0")
            }

            NavigationStack {
                CheckInsView()
                    .onAppear {
                        print("📍 CheckInsView appeared")
                        print("📍 CheckInsView onAppear: Thread=MAIN")
                    }
                    .onTapGesture {
                        print("📍 CHECKINS VIEW TAPPED - UI should be responsive")
                    }
            }
            .tabItem {
                Label("Check-Ins", systemImage: "mappin.and.ellipse")
            }
            .tag(1)
            .onTapGesture {
                print("📍 CHECKINS TAB ITEM TAPPED - should switch to tab 1")
            }

            NavigationStack {
                ConversationsListView()
                    .onAppear {
                        print("💬 ConversationsListView appeared")
                        print("💬 ConversationsListView onAppear: Thread=MAIN")
                    }
                    .onTapGesture {
                        print("💬 CONVERSATIONS VIEW TAPPED - UI should be responsive")
                    }
            }
            .tabItem {
                Label("Message", systemImage: "message.fill")
            }
            .tag(2)
            .onTapGesture {
                print("💬 MESSAGES TAB ITEM TAPPED - should switch to tab 2")
            }

            NavigationStack {
                ProfileView()
                    .onAppear {
                        print("👤 ProfileView appeared")
                        print("👤 ProfileView onAppear: Thread=MAIN")
                    }
                    .onTapGesture {
                        print("👤 PROFILE VIEW TAPPED - UI should be responsive")
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(3)
            .onTapGesture {
                print("👤 PROFILE TAB ITEM TAPPED - should switch to tab 3")
            }
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 Tab changed from \(oldValue) to \(newValue)")
            print("🔄 Tab change: Thread=MAIN")
        }
        .onAppear {
            print("🎯 MainTabView body appeared - modal state: \(showSubscriptionModal)")
            print("🎯 MainTabView onAppear: Thread=MAIN")
        }
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionModalView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .onAppear {
                    print("💰 SubscriptionModalView appeared")
                }
        }
        .onTapGesture {
            print("🎯 MAIN TAB VIEW BACKGROUND TAPPED - UI should be responsive")
        }
        .gesture(
            // Add a drag gesture to detect if gestures are working
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    print("🎯 DRAG GESTURE DETECTED on MainTabView - direction: \(value.translation)")
                }
        )
    }
}

#Preview {
    MainTabView()
}

#Preview("Show Modal Initially") {
    MainTabView(showSubscriptionModalInitially: true)
} 