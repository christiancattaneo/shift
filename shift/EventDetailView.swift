import SwiftUI

struct EventDetailView: View {
    // Passed in data
    let event: AdaloEvent
    
    // Real data services
    @StateObject private var membersService = FirebaseMembersService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    
    @State private var searchText = ""
    @State private var isCheckedIn = false
    @Environment(\.dismiss) var dismiss // To handle the custom back button
    
    // Filter members by search and optionally by location
    var filteredMembers: [FirebaseMember] {
        let members = searchText.isEmpty ? membersService.members : membersService.members.filter { member in
            member.firstName.localizedCaseInsensitiveContains(searchText) ||
            (member.city?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        // If event has a city/location, try to filter by that
        if let eventLocation = event.eventLocation, !eventLocation.isEmpty {
            let locationMembers = members.filter { member in
                member.city?.localizedCaseInsensitiveContains(eventLocation) ?? false
            }
            // Return location-filtered members if we have any, otherwise all members
            return locationMembers.isEmpty ? members : locationMembers
        }
        
        return members
    }
    
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
                
                // Event Image
                if let imageURL = event.imageURL {
                    AsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(15)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .cornerRadius(15)
                            .overlay(
                                VStack {
                                    Image(systemName: "photo")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    Text("Loading image...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    .padding(.horizontal)
                }
                
                // Event Details
                VStack(spacing: 8) {
                    Text(event.name)
                        .font(.largeTitle.weight(.bold))
                        .multilineTextAlignment(.center)
                    
                    if let venueName = event.venueName, !venueName.isEmpty {
                        Text(venueName)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if let address = event.address, !address.isEmpty {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text(address)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 1)
                    }
                    
                    // Event timing information
                    if let eventDate = event.eventDate, !eventDate.isEmpty {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            Text(eventDate)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                    
                    if let startTime = event.eventStartTime, !startTime.isEmpty {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                            Text(startTime)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                    
                    if let category = event.eventCategory, !category.isEmpty {
                        Text(category)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                            .padding(.top, 4)
                    }
                    
                    if let isFree = event.isEventFree {
                        Text(isFree ? "Free Event" : "Paid Event")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(isFree ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .foregroundColor(isFree ? .green : .orange)
                            .cornerRadius(8)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)

                // Check In/Out Button
                Button {
                    if let currentUser = FirebaseUserSession.shared.currentUser,
                       let userId = currentUser.id {
                        let eventId = String(event.id) // Convert Int to String directly
                        if isCheckedIn {
                            // Check out logic - for now just toggle
                            isCheckedIn = false
                        } else {
                            // Check in
                            checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                                if success {
                                    isCheckedIn = true
                                } else {
                                    print("Check-in failed: \(error ?? "Unknown error")")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(isCheckedIn ? "CHECKED IN" : "CHECK IN")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundColor(isCheckedIn ? .black : .white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(isCheckedIn ? checkOutColor : Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                // Member count and location info
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundColor(.blue)
                        Text("People nearby")
                            .font(.headline)
                        Spacer()
                        Text("\(filteredMembers.count)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    if let eventLocation = event.eventLocation, !eventLocation.isEmpty {
                        Text("Showing people in \(eventLocation)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Search Bar
                TextField("Search people...", text: $searchText)
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
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "multiply.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                    )
                    .padding(.horizontal)
                
                // Members Grid
                if membersService.isLoading {
                    ProgressView("Loading people...")
                        .padding()
                } else if filteredMembers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No people found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try adjusting your search or check back later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredMembers, id: \.uniqueID) { member in
                            MemberCardView(member: member)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Data source indicator
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Real data from Firebase • \(filteredMembers.count) people")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 10)
                }
                
                // Error handling
                if let errorMessage = membersService.errorMessage {
                    VStack {
                        Text("Unable to load people")
                            .font(.headline)
                            .foregroundColor(.red)
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
                    .padding(.horizontal)
                }
            }
            .padding(.top) // Add padding to the top of the VStack
        }
        .navigationBarHidden(true) // Hide the default navigation bar
        .navigationBarBackButtonHidden(true) // Hide the default back button
        .onAppear {
            membersService.fetchMembers()
            checkInsService.fetchCheckIns()
            
            // Check if user is already checked in to this event
            if let currentUser = FirebaseUserSession.shared.currentUser,
               let userId = currentUser.id {
                let eventId = String(event.id)
                isCheckedIn = checkInsService.checkIns.contains { checkIn in
                    checkIn.userId == userId && checkIn.eventId == eventId && checkIn.isActive == true
                }
            }
        }
        .refreshable {
            membersService.fetchMembers()
            checkInsService.fetchCheckIns()
        }
    }
}

#Preview {
    // Wrap in NavigationView for the dismiss environment variable to work in preview
    NavigationView {
        EventDetailView(event: AdaloEvent(
            id: 1,
            eventName: "512 Coffee Club",
            eventLocation: "Austin, TX"
        ))
    }
} 