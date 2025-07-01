import SwiftUI

struct MainTabView: View {
    @State private var showSubscriptionModal: Bool = false
    @State private var selectedTab: Int = 0
    
    init(showSubscriptionModalInitially: Bool = false) {
        _showSubscriptionModal = State(initialValue: showSubscriptionModalInitially)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MembersView()
            }
            .tabItem {
                Label("Members", systemImage: "person.2.fill")
            }
            .tag(0)

            NavigationStack {
                CheckInsView()
            }
            .tabItem {
                Label("Events", systemImage: "mappin.and.ellipse")
            }
            .tag(1)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .tag(2)
        }
        .tint(.blue)
        .onAppear {
            setupTabBarAppearance()
        }
        .sheet(isPresented: $showSubscriptionModal) {
            SubscriptionModalView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Configure tab bar item appearance
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    MainTabView()
}

#Preview("With Subscription Modal") {
    MainTabView(showSubscriptionModalInitially: true)
} 