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
        
        VStack(spacing: 0) {
            // Debug tab selector for testing - TEMPORARY
            HStack {
                Button("Members(0)") {
                    print("🔄 DEBUG: Manually setting tab to 0")
                    selectedTab = 0
                }
                .background(selectedTab == 0 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .padding(4)
                
                Button("Check-Ins(1)") {
                    print("🔄 DEBUG: Manually setting tab to 1")
                    selectedTab = 1
                }
                .background(selectedTab == 1 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .padding(4)
                
                Button("Messages(2)") {
                    print("🔄 DEBUG: Manually setting tab to 2")
                    selectedTab = 2
                }
                .background(selectedTab == 2 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .padding(4)
                
                Button("Profile(3)") {
                    print("🔄 DEBUG: Manually setting tab to 3")
                    selectedTab = 3
                }
                .background(selectedTab == 3 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .padding(4)
            }
            .padding(.horizontal)
            .background(Color.yellow.opacity(0.3))
            
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
            }
            .accentColor(.blue)
            .onChange(of: selectedTab) { oldValue, newValue in
                print("🔄 🎯 TAB SELECTION CHANGED: \(oldValue) → \(newValue)")
                print("🔄 Tab change: Thread=MAIN")
                switch newValue {
                case 0: print("🔄 Now showing: Members tab")
                case 1: print("🔄 Now showing: Check-Ins tab")
                case 2: print("🔄 Now showing: Messages tab")
                case 3: print("🔄 Now showing: Profile tab")
                default: print("🔄 Unknown tab: \(newValue)")
                }
            }
        } // Close VStack
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
    }
}

#Preview {
    MainTabView()
}

#Preview("Show Modal Initially") {
    MainTabView(showSubscriptionModalInitially: true)
} 