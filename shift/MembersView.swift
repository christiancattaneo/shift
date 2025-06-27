import SwiftUI

struct MembersView: View {
    @State private var searchText = ""
    @StateObject private var membersService = FirebaseMembersService()
    
    // Computed property for filtered members  
    var filteredMembers: [FirebaseMember] {
        if searchText.isEmpty {
            return membersService.members
        } else {
            return membersService.members.filter { 
                $0.firstName.localizedCaseInsensitiveContains(searchText) ||
                ($0.city?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.attractedTo?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

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
                    if membersService.isLoading {
                        VStack {
                            ProgressView("Loading members from Firebase...")
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Fetching real data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if filteredMembers.isEmpty {
                        VStack {
                            if membersService.errorMessage != nil {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Unable to load members")
                                    .font(.headline)
                                Text("Check your internet connection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "person.3")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No members found")
                                    .font(.headline)
                                Text("Try adjusting your search")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredMembers, id: \.uniqueID) { member in
                                MemberCardView(member: member)
                            }
                        }
                        
                        // Data source indicator
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Loaded \(filteredMembers.count) members from Firebase")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 10)
                    }
                    
                    // Error message
                    if let errorMessage = membersService.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Connection Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Button("Retry") {
                                membersService.fetchMembers()
                            }
                            .padding(.top, 5)
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }

                }
                .padding()
            }
            .navigationBarHidden(true) // Hide default nav bar for custom header
        }
        .onAppear {
            membersService.fetchMembers()
        }
        .refreshable {
            membersService.fetchMembers()
        }
    }
}

// Card View for each member
struct MemberCardView: View {
    let member: FirebaseMember

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image
            AsyncImage(url: member.profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .clipped()
            } placeholder: {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                    
                    VStack {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Name and Age
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // City
                if let city = member.city, !city.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Attracted To
                if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                    Text("Attracted to: \(attractedTo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Approach Tip
                if let approachTip = member.approachTip, !approachTip.isEmpty {
                    Text(approachTip)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
                
                // Instagram Handle
                if let instagram = member.instagramHandle, !instagram.isEmpty {
                    HStack {
                        Image(systemName: "camera")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("@\(instagram)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 2)
                }
                
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color(.systemGray6)) // Background for the card
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    MembersView()
} 