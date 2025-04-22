import SwiftUI

struct EventDetailView: View {
    // Passed in data
    let place: EventPlace
    
    // Placeholder data for members at this location
    // Replace with actual data logic later
    let membersAtLocation: [Member] = [
        Member(name: "Marin", imageName: "person.fill", attractedTo: "female", approach: "playing a game of tag"),
        Member(name: "macey", imageName: "person.fill", attractedTo: "male", approach: "a game of rock paper scissors. best 2/3?")
    ]
    
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss // To handle the custom back button
    
    // Define grid layout (same as MembersView)
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Define the check-out button color
    let checkOutColor = Color(red: 0.8, green: 1.0, blue: 0.1) // Lime green approximation

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Custom Header
                HStack {
                    Button {
                        dismiss() // Action for the back button
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.blue) // Or .primary
                    }
                    Spacer()
                    Image("shiftlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 30)
                }
                .padding(.horizontal)
                
                // Place Details
                VStack {
                    Text(place.name)
                        .font(.largeTitle.weight(.bold))
                    // Placeholder Subtitle
                    Text("Cabana Club") // This isn't in EventPlace struct yet
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(place.address)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }
                .padding(.horizontal)

                // Check Out Button
                Button {
                    // TODO: Implement Check Out Logic
                    print("Check Out Tapped")
                } label: {
                    Text("+ CHECK OUT")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black) // Black text on lime green
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(checkOutColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                // Search Bar
                TextField("Search...", text: $searchText)
                    .padding(10)
                    .padding(.horizontal, 25) 
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                            // Add clear button if needed
                        }
                    )
                    .padding(.horizontal)
                
                // Members Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(membersAtLocation) { member in
                        // Reuse the MemberCardView from MembersView
                        MemberCardView(member: member)
                    }
                }
                .padding(.horizontal)
                
            }
            .padding(.top) // Add padding to the top of the VStack
        }
        .navigationBarHidden(true) // Hide the default navigation bar
        .navigationBarBackButtonHidden(true) // Hide the default back button
    }
}

// Preview needs an example EventPlace
#Preview {
    // Wrap in NavigationView for the dismiss environment variable to work in preview
    NavigationView {
        EventDetailView(place: EventPlace(name: "512 Coffee Club", address: "5012 E 7th St, Austin, TX 78702, USA"))
    }
} 