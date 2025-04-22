import SwiftUI

// Placeholder data structure
struct Member: Identifiable {
    let id = UUID()
    let name: String
    let imageName: String // Use system images or asset names later
    let attractedTo: String
    let approach: String
}

struct MembersView: View {
    @State private var searchText = ""

    // Placeholder data - replace with actual data source later
    let members: [Member] = [
        Member(name: "Omeed", imageName: "person.fill", attractedTo: "Female", approach: "Say hello"),
        Member(name: "Caroline", imageName: "person.fill", attractedTo: "male", approach: "I tend to go for the personality hire"),
        Member(name: "User 3", imageName: "person.fill", attractedTo: "Anyone", approach: "Compliments"),
        Member(name: "User 4", imageName: "person.fill", attractedTo: "Female", approach: "Ask about their day")
    ]

    // Define grid layout
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var body: some View {
        NavigationView { // Each tab can have its own NavigationView if needed
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Header
                    HStack {
                        Text("Members")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        Image("shiftlogo") // Assuming logo is in assets
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                    }
                    Text("Explore single members")
                        .foregroundColor(.secondary)

                    // Search Bar Placeholder
                    TextField("Search Members...", text: $searchText)
                        .padding(10)
                        .padding(.horizontal, 25) // Indent text for icon space
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        self.searchText = ""
                                    }) {
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                        )
                        .padding(.top, 5)

                    // Members Grid
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(members) { member in
                            MemberCardView(member: member)
                        }
                    }

                }
                .padding()
            }
            .navigationBarHidden(true) // Hide default nav bar for custom header
        }
    }
}

// Card View for each member
struct MemberCardView: View {
    let member: Member

    var body: some View {
        VStack(alignment: .leading) {
            // Image placeholder
            Image(member.imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .clipped()
                .background(Color.gray.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)
                Text("Attracted to: \(member.attractedTo)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("How to approach me: \(member.approach)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
            }
            .padding(8)
        }
        .background(Color(.systemGray6)) // Background for the card
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}

#Preview {
    MembersView()
} 