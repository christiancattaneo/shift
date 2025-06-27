import SwiftUI

struct FirebaseEventDetailView: View {
    let event: FirebaseEvent
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @State private var isCheckedIn = false
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
                    
                    Spacer(minLength: 20)
                    
                    // Check-in Button
                    Button(action: {
                        if isCheckedIn {
                            // Check out logic would go here
                            isCheckedIn = false
                        } else {
                            // Check in
                            if let currentUser = FirebaseUserSession.shared.currentUser,
                               let userId = currentUser.id,
                               let eventId = event.id {
                                checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                                    if success {
                                        isCheckedIn = true
                                    }
                                }
                            }
                        }
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
    }
}

#Preview {
    NavigationView {
        FirebaseEventDetailView(
            event: FirebaseEvent(
                id: "1",
                eventName: "Tech Meetup",
                venueName: "WeWork",
                eventLocation: "123 Main St, San Francisco, CA",
                eventStartTime: "7:00 PM",
                eventEndTime: "9:00 PM"
            )
        )
    }
} 