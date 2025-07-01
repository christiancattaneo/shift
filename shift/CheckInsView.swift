import SwiftUI
import MapKit
import Combine

// MARK: - Helper Functions

// Global helper function to parse event date string to Date
func parseEventDate(_ dateString: String) -> Date? {
    let dateFormats = [
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "yyyy-MM-dd HH:mm:ss",
        "MM/dd/yyyy HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss"
    ]
    
    for format in dateFormats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        if let date = formatter.date(from: dateString) {
            return date
        }
    }
    
    return nil
}

struct CheckInsView: View {
    @State private var region = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.758896, longitude: -73.985130),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @StateObject private var eventsService = FirebaseEventsService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    
    private let filters = ["All", "Tonight", "This Week", "Nearby"]
    
    var filteredEvents: [FirebaseEvent] {
        var events = eventsService.events
        
        // Apply search filter
        if !searchText.isEmpty {
            events = events.filter { event in
                (event.eventName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.eventLocation?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.venueName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply date/location filters
        switch selectedFilter {
        case "Tonight":
            return events.filter { event in
                guard let eventDateString = event.eventDate,
                      let eventDate = parseEventDate(eventDateString) else { return false }
                return Calendar.current.isDateInToday(eventDate)
            }
        case "This Week":
            return events.filter { event in
                guard let eventDateString = event.eventDate,
                      let eventDate = parseEventDate(eventDateString) else { return false }
                return Calendar.current.isDate(eventDate, equalTo: Date(), toGranularity: .weekOfYear)
            }
        case "Nearby":
            // For now, return all events. Could implement actual location filtering
            return events
        default:
            return events
        }
    }


    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Section
                headerSection
                
                // Map Section
                mapSection
                
                // Content Section
                if eventsService.isLoading {
                    loadingSection
                } else if filteredEvents.isEmpty {
                    emptyStateSection
                } else {
                    eventsListSection
                }
            }
            .navigationTitle("Discover Events")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshEvents()
            }
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - UI Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .medium))
                
                TextField("Search events & places...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filters, id: \.self) { filter in
                        FilterPill(
                            title: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Results Counter
            if !filteredEvents.isEmpty {
                HStack {
                    Text("\(filteredEvents.count) events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    private var mapSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Nearby Events")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("View All") {
                    // TODO: Expand map view
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            
            Map(position: $region)
                .frame(height: 200)
                .cornerRadius(16)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Finding events near you...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No events found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your filters or check back later for events in your area")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Refresh") {
                Task {
                    await refreshEvents()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var eventsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredEvents, id: \.uniqueID) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        eventsService.fetchEvents()
        checkInsService.fetchCheckIns()
    }
    
    private func refreshEvents() async {
        eventsService.fetchEvents()
        checkInsService.fetchCheckIns()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Supporting Views

struct EventCardView: View {
    let event: FirebaseEvent
    @State private var isCheckedIn = false
    @State private var checkInCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image/Header
            ZStack(alignment: .topTrailing) {
                // Event Image with fallback gradient
                AsyncImage(url: event.imageURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white.opacity(0.8))
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.3), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    case .failure(_):
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 120)
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.eventName ?? "Event")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            if let venueName = event.venueName {
                                HStack(spacing: 4) {
                                    Image(systemName: "location.fill")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text(venueName)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.9))
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Event Time/Date
                    if let eventDateString = event.eventDate,
                       let eventDate = parseEventDate(eventDateString) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Text(formatEventDate(eventDate))
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Event Type Badge
                VStack {
                    Text("EVENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(12)
            }
            
            // Event Details
            VStack(spacing: 12) {
                if let address = event.eventLocation {
                    HStack {
                        Image(systemName: "mappin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Spacer()
                    }
                }
                
                // Check-in Section
                HStack {
                    // Check-in Count
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(checkInCount) checked in")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Check-in Button
                    Button(action: toggleCheckIn) {
                        HStack(spacing: 6) {
                            Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "plus.circle")
                                .font(.subheadline)
                            Text(isCheckedIn ? "Checked In" : "Check In")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isCheckedIn ? .white : .blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            isCheckedIn ? 
                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            checkIfUserCheckedIn()
            loadCheckInCount()
        }
    }
    
    func toggleCheckIn() {
        Haptics.lightImpact()
        
        if isCheckedIn {
            // Check out logic - for now just toggle state
            isCheckedIn = false
            checkInCount = max(0, checkInCount - 1)
        } else {
            // Check in logic - for now just toggle state
            Haptics.successNotification()
            isCheckedIn = true
            checkInCount += 1
        }
    }
    
    func checkIfUserCheckedIn() {
        // TODO: Implement check if current user is checked into this event
        isCheckedIn = false
    }
    
    func loadCheckInCount() {
        // TODO: Load actual check-in count for this event
        checkInCount = Int.random(in: 2...15)
    }
    
    func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            formatter.timeStyle = .short
            return "Today at \(formatter.string(from: date))"
        } else if Calendar.current.isDateInTomorrow(date) {
            formatter.timeStyle = .short
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - FilterPill Component
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Firebase Services (Placeholder)
class FirebaseEventsService: ObservableObject {
    @Published var events: [FirebaseEvent] = []
    @Published var isLoading = false
    
    func fetchEvents() {
        isLoading = true
        // TODO: Implement Firebase event fetching
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isLoading = false
            // Add mock data for now
            self.events = []
        }
    }
}

class FirebaseCheckInsService: ObservableObject {
    @Published var isLoading = false
    
    func fetchCheckIns() {
        // TODO: Implement Firebase check-ins fetching
    }
    
    func checkIn(userId: String, eventId: String, completion: @escaping (Bool, String?) -> Void) {
        // TODO: Implement Firebase check-in
        completion(true, nil)
    }
}

// MARK: - Event Detail View (Placeholder)
struct EventDetailView: View {
    let event: FirebaseEvent
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                AsyncImage(url: event.imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 300)
                            .clipped()
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(event.eventName ?? "Event")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let venueName = event.venueName {
                        Text(venueName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = event.eventLocation {
                        Text(location)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CheckInsView()
} 