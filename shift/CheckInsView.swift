import SwiftUI
import MapKit
import Combine



struct CheckInsView: View {
    // Use MapCameraPosition for iOS 17+
    @State private var region = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.758896, longitude: -73.985130),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var searchText = ""
    @StateObject private var eventsService = FirebaseEventsService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    
    // Filter events based on search
    var filteredEvents: [FirebaseEvent] {
        if searchText.isEmpty {
            return eventsService.events
        } else {
            return eventsService.events.filter { event in
                event.name.localizedCaseInsensitiveContains(searchText) ||
                (event.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
                // Custom Header
                VStack(spacing: 15) {
                    HStack {
                        Text("Check-Ins")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search places", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // Map View
                Map(position: $region)
                    .frame(height: 250)
                    .cornerRadius(15)
                    .padding(.horizontal)
                
                // Events/Places List
                if eventsService.isLoading {
                    Spacer()
                    ProgressView("Loading events...")
                    Spacer()
                } else if filteredEvents.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No events nearby")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Check back later for events in your area!")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredEvents, id: \.uniqueID) { event in
                            NavigationLink(
                                destination: FirebaseEventDetailView(event: event)
                            ) {
                                EventRow(event: event)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        .onAppear {
            eventsService.fetchEvents()
            checkInsService.fetchCheckIns()
        }
    }
}

// Updated to use FirebaseEvent
struct EventRow: View {
    let event: FirebaseEvent
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @State private var isCheckedIn = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Event icon
            Image(systemName: "mappin.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let address = event.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if let venueName = event.venueName {
                    Text(venueName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Check-in button
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
                Text(isCheckedIn ? "Check Out" : "Check In")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isCheckedIn ? .black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isCheckedIn ? Color.yellow : Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}





#Preview {
    CheckInsView()
} 