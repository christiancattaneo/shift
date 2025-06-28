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
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    print("🎯 TABVIEW RECEIVED TAP - selectedTab is: \(selectedTab)")
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    print("🎯 DRAG GESTURE on TabView - direction: \(value.translation)")
                    print("🎯 Current selectedTab: \(selectedTab)")
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