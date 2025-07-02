import SwiftUI

struct FirebaseEventDetailView: View {
    let event: FirebaseEvent
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @State private var isCheckedIn = false
    @State private var checkInCount = 0
    @State private var attendees: [FirebaseMember] = []
    @State private var isLoadingAttendees = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Image
                AsyncImage(url: event.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 250)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 250)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Event Image")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    // Event Title
                    Text(event.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Venue
                    if let venue = event.venueName {
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.blue)
                            Text(venue)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Location
                    if let location = event.eventLocation {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.red)
                            Text(location)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Time
                    if let startTime = event.eventStartTime {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.green)
                            Text("Starts at \(startTime)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if let endTime = event.eventEndTime {
                                Text("- \(endTime)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Date
                    if let date = event.eventDate {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.purple)
                            Text(date)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Category
                    if let category = event.eventCategory {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(.orange)
                            Text(category)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Free indicator
                    if let isFree = event.isEventFree, isFree {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Free Event")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Check-in Button
                    Button(action: {
                        toggleCheckIn()
                    }) {
                        HStack {
                            Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "location.circle")
                            Text(isCheckedIn ? "Checked In" : "Check In to Event")
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCheckedIn ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCheckedIn ? Color.yellow : Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Attendees Section
                    attendeesSection
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            setupEventDetail()
        }
    }
    
    // MARK: - Attendees Section
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Who's Going")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("(\(checkInCount))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                if isLoadingAttendees {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Current User Card - Show prominently when checked in
            if isCheckedIn, let currentUser = FirebaseUserSession.shared.currentUser {
                CurrentUserMemberCard(user: currentUser, type: "event")
                    .padding(.vertical, 8)
            }
            
            // Check-in status message
            if !attendees.isEmpty || isCheckedIn {
                HStack(spacing: 8) {
                    Image(systemName: isCheckedIn ? "eye" : "eye.slash")
                        .font(.caption)
                        .foregroundColor(isCheckedIn ? .green : .orange)
                    
                    Text(isCheckedIn ? 
                         "You can see who's going because you're checked in" : 
                         "Check in to see who else is going")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            
            if attendees.isEmpty && !isLoadingAttendees && !isCheckedIn {
                VStack(spacing: 12) {
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No one has checked in yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Be the first to check in!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if attendees.count > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attendees, id: \.uniqueID) { member in
                            EventAttendeeCardView(member: member, currentUserCheckedIn: isCheckedIn)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Helper Functions
    private func setupEventDetail() {
        checkIfUserCheckedIn()
        loadCheckInCount()
        loadAttendees()
    }
    
    private func toggleCheckIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else {
            print("❌ Missing user or event ID")
            return
        }
        
        if isCheckedIn {
            // Check out logic
            checkInsService.checkOut(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    if success {
                        isCheckedIn = false
                        loadCheckInCount()
                    }
                }
            }
        } else {
            // Check in
            checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    if success {
                        isCheckedIn = true
                        loadCheckInCount()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else { return }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { checkedIn in
            DispatchQueue.main.async {
                isCheckedIn = checkedIn
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let eventId = event.id else { return }
        
        checkInsService.getCombinedCheckInCount(for: eventId, itemType: "event") { currentCount, historicalCount in
            DispatchQueue.main.async {
                checkInCount = historicalCount
            }
        }
    }
    
    private func loadAttendees() {
        guard let eventId = event.id else { return }
        
        isLoadingAttendees = true
        checkInsService.getMembersAtEvent(eventId) { members in
            DispatchQueue.main.async {
                attendees = members
                isLoadingAttendees = false
            }
        }
    }
}

// MARK: - Event Attendee Card View
struct EventAttendeeCardView: View {
    let member: FirebaseMember
    let currentUserCheckedIn: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile Image with conditional blur
            CachedAsyncImage(url: member.profileImageURL) { image in
                let _ = print("✅ CACHED ASYNC: '\(member.firstName)' - Image loaded successfully in EventDetailView")
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .blur(radius: currentUserCheckedIn ? 0 : 8)
                    .overlay(
                        Circle()
                            .stroke(currentUserCheckedIn ? Color.blue : Color.gray, lineWidth: 2)
                    )
            } placeholder: {
                let _ = print("🖼️ CACHED ASYNC: '\(member.firstName)' - Loading placeholder in EventDetailView, URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .blur(radius: currentUserCheckedIn ? 0 : 8)
                    .overlay(
                        Text(member.firstName.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .blur(radius: currentUserCheckedIn ? 0 : 6)
                    )
                    .overlay(
                        Circle()
                            .stroke(currentUserCheckedIn ? Color.blue : Color.gray, lineWidth: 2)
                    )
            }
            
            // Lock icon overlay if not checked in
            if !currentUserCheckedIn {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 20, height: 20)
                    )
                    .offset(x: 20, y: -45)
            }
            
            // Member Info with conditional blur
            VStack(spacing: 2) {
                Text(currentUserCheckedIn ? member.firstName : "???")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if let age = member.age {
                    Text(currentUserCheckedIn ? "\(age)" : "??")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let city = member.city {
                    Text(currentUserCheckedIn ? city : "???")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let tip = member.approachTip, !tip.isEmpty {
                    Text(currentUserCheckedIn ? tip : "???")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.tail)
                }
            }
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Current User Member Card
struct CurrentUserMemberCard: View {
    let user: FirebaseUser
    let type: String // "event" or "place"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with "You're Here!" indicator
            HStack(spacing: 8) {
                Image(systemName: type == "event" ? "calendar.badge.checkmark" : "location.badge.checkmark")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("You're \(type == "event" ? "Going!" : "Here!")")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // User Profile Content
            HStack(spacing: 16) {
                // Profile Image
                AsyncImage(url: URL(string: user.profilePhoto ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    default:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(user.firstName?.prefix(1).uppercased() ?? "?")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(user.firstName ?? "Unknown")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        if let age = user.age {
                            Text("\(age)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let city = user.city {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let howToApproach = user.howToApproachMe, !howToApproach.isEmpty {
                        Text(howToApproach)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Instagram handle if available
                    if let instagram = user.instagramHandle, !instagram.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "camera")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Text(instagram.hasPrefix("@") ? instagram : "@\(instagram)")
                                .font(.caption)
                                .foregroundColor(.purple)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    NavigationView {
        FirebaseEventDetailView(
            event: FirebaseEvent(
                eventName: "Tech Meetup",
                venueName: "WeWork",
                eventLocation: "123 Main St, San Francisco, CA",
                eventStartTime: "7:00 PM",
                eventEndTime: "9:00 PM"
            )
        )
    }
} 