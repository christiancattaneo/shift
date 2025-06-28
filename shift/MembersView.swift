import SwiftUI

struct MembersView: View {
    @State private var searchText = ""
    @ObservedObject private var membersService = FirebaseMembersService.shared
    
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
        ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Header
                    HStack {
                        Text("Members")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .onTapGesture {
                                print("👥 MEMBERS TITLE TAPPED - UI should be responsive")
                            }
                        Spacer()
                        
                        // Debug refresh button
                        Button("🔄") {
                            print("🔄 Manual refresh triggered")
                            print("🔄 Manual refresh: Thread=MAIN")
                            membersService.refreshMembers()
                        }
                        .font(.title2)
                        .onAppear {
                            print("🔄 Refresh button appeared")
                        }
                        
                        Image("shiftlogo") // Assuming logo is in assets
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                            .onTapGesture {
                                print("👥 LOGO TAPPED - UI should be responsive")
                            }
                    }
                    .onAppear {
                        print("👥 Header appeared")
                    }
                    
                    Text("Explore single members")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            print("👥 SUBTITLE TAPPED - UI should be responsive")
                        }

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
                                    .onTapGesture {
                                        print("👥 SEARCH ICON TAPPED - UI should be responsive")
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        print("👥 CLEAR SEARCH TAPPED")
                                        self.searchText = ""
                                    }) {
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                    .onAppear {
                                        print("👥 Clear search button appeared")
                                    }
                                }
                            }
                        )
                        .padding(.top, 5)
                        .onAppear {
                            print("👥 Search bar appeared")
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            print("👥 Search text changed: '\(oldValue)' -> '\(newValue)'")
                        }

                    // Members Grid
                    if membersService.isLoading {
                        VStack {
                            ProgressView("Loading members from Firebase...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .onTapGesture {
                                    print("👥 LOADING PROGRESS TAPPED - UI should be responsive")
                                }
                            Text("Fetching real data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                                .onTapGesture {
                                    print("👥 LOADING TEXT TAPPED - UI should be responsive")
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            print("👥 Loading state appeared")
                        }
                    } else if filteredMembers.isEmpty {
                        VStack {
                            if membersService.errorMessage != nil {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        print("👥 ERROR ICON TAPPED - UI should be responsive")
                                    }
                                Text("Unable to load members")
                                    .font(.headline)
                                    .onTapGesture {
                                        print("👥 ERROR TEXT TAPPED - UI should be responsive")
                                    }
                                Text("Check your internet connection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        print("👥 ERROR SUBTITLE TAPPED - UI should be responsive")
                                    }
                            } else {
                                Image(systemName: "person.3")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS ICON TAPPED - UI should be responsive")
                                    }
                                Text("No members found")
                                    .font(.headline)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS TEXT TAPPED - UI should be responsive")
                                    }
                                Text("Try adjusting your search")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS SUBTITLE TAPPED - UI should be responsive")
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            print("👥 Empty state appeared")
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredMembers, id: \.uniqueID) { member in
                                MemberCardView(member: member)
                                    .onTapGesture {
                                        print("👥 MEMBER CARD TAPPED: \(member.firstName) - UI should be responsive")
                                    }
                                    .onAppear {
                                        print("👥 Member card appeared: \(member.firstName)")
                                    }
                            }
                        }
                        .onAppear {
                            print("👥 Members grid appeared with \(filteredMembers.count) members")
                        }
                        
                        // Data source indicator
                        VStack(spacing: 5) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .onTapGesture {
                                        print("👥 SUCCESS ICON TAPPED - UI should be responsive")
                                    }
                                Text("Loaded \(filteredMembers.count) members from Firebase")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        print("👥 SUCCESS TEXT TAPPED - UI should be responsive")
                                    }
                            }
                            
                            // Debug info
                            Text("Total in service: \(membersService.members.count) • Loading: \(membersService.isLoading)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    print("👥 DEBUG INFO TAPPED - UI should be responsive")
                                }
                        }
                        .padding(.top, 10)
                        .onAppear {
                            print("👥 Data source indicator appeared")
                        }
                    }
                    
                    // Error message
                    if let errorMessage = membersService.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        print("👥 ERROR ICON TAPPED - UI should be responsive")
                                    }
                                Text("Connection Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        print("👥 ERROR TITLE TAPPED - UI should be responsive")
                                    }
                            }
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .onTapGesture {
                                    print("👥 ERROR MESSAGE TAPPED - UI should be responsive")
                                }
                            
                            Button("Retry") {
                                print("👥 RETRY BUTTON TAPPED")
                                print("👥 RETRY: Thread=MAIN")
                                membersService.refreshMembers()
                            }
                            .padding(.top, 5)
                            .buttonStyle(.bordered)
                            .onAppear {
                                print("👥 Retry button appeared")
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .onAppear {
                            print("👥 Error message appeared: \(errorMessage)")
                        }
                    }

                }
                .padding()
                .onAppear {
                    print("👥 Main VStack appeared")
                }
            }
        .onAppear {
            print("👥 MembersView onAppear - calling fetchMembers")
            print("👥 MembersView onAppear: Thread=MAIN")
            membersService.fetchMembers()
        }
        .refreshable {
            print("👥 Pull to refresh triggered")
            print("👥 Pull to refresh: Thread=MAIN")
            membersService.refreshMembers()
        }
        .onTapGesture {
            print("👥 MEMBERS VIEW BACKGROUND TAPPED - UI should be responsive")
        }
        .gesture(
            // Add a drag gesture to detect if gestures are working
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    print("👥 DRAG GESTURE DETECTED on MembersView - direction: \(value.translation)")
                }
        )
    }
}

// Card View for each member
struct MemberCardView: View {
    let member: FirebaseMember

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image with detailed logging
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .empty:
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
                    .onAppear {
                        print("🖼️ Image loading started for \(member.firstName)")
                        print("🖼️ URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                        .onAppear {
                            print("✅ Image loaded successfully for \(member.firstName)")
                        }
                case .failure(let error):
                    ZStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: 150)
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .onAppear {
                        print("❌ Image failed to load for \(member.firstName): \(error.localizedDescription)")
                        print("❌ Failed URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                    }
                @unknown default:
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                        Image(systemName: "questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    .onAppear {
                        print("❓ Unknown AsyncImage phase for \(member.firstName)")
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Name and Age
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            print("👥 MEMBER NAME TAPPED: \(member.firstName) - UI should be responsive")
                        }
                    
                    Spacer()
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                print("👥 MEMBER AGE TAPPED: \(member.firstName) - UI should be responsive")
                            }
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
                    .onTapGesture {
                        print("👥 MEMBER CITY TAPPED: \(member.firstName) - UI should be responsive")
                    }
                }
                
                // Attracted To
                if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                    Text("Attracted to: \(attractedTo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .onTapGesture {
                            print("👥 MEMBER ATTRACTION TAPPED: \(member.firstName) - UI should be responsive")
                        }
                }
                
                // Approach Tip
                if let approachTip = member.approachTip, !approachTip.isEmpty {
                    Text(approachTip)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .padding(.top, 2)
                        .onTapGesture {
                            print("👥 MEMBER APPROACH TIP TAPPED: \(member.firstName) - UI should be responsive")
                        }
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
                    .onTapGesture {
                        print("👥 MEMBER INSTAGRAM TAPPED: \(member.firstName) - UI should be responsive")
                    }
                }
                
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .onTapGesture {
                            print("👥 MEMBER CHEVRON TAPPED: \(member.firstName) - UI should be responsive")
                        }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color(.systemGray6)) // Background for the card
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            print("👥 MEMBER CARD BACKGROUND TAPPED: \(member.firstName) - UI should be responsive")
        }
    }
}

#Preview {
    MembersView()
} 