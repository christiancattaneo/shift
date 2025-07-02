import SwiftUI
import Combine
import CoreLocation

// MARK: - Notification Extensions
extension Notification.Name {
    static let checkInStatusChanged = Notification.Name("checkInStatusChanged")
}

// MARK: - Cached AsyncImage Component
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = false
    
    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, !isLoading else { return }
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let uiImage = UIImage(data: data) {
                    cachedImage = uiImage
                }
            }
        }.resume()
    }
}



// MARK: - Main CheckInsView
struct CheckInsView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedEvent: FirebaseEvent? = nil
    @State private var showLocationPermissionAlert = false
    @StateObject private var eventsService = FirebaseEventsService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var userSession = FirebaseUserSession.shared
    
    private let filters = ["All", "Tonight", "This Week", "In City", "Nearby"]
    
    var filteredEvents: [FirebaseEvent] {
        var events = eventsService.events
        print("🎯 EVENTS: Starting with \(events.count) total events from service")
        
        // Debug: Print first few event names
        for (index, event) in events.prefix(5).enumerated() {
            print("🎯 EVENTS: Event \(index): '\(event.eventName ?? "nil")' - venue: '\(event.venueName ?? "nil")'")
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            let beforeSearch = events.count
            events = events.filter { event in
                (event.eventName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.eventLocation?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (event.venueName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            print("🔍 EVENTS: After search '\(searchText)': \(events.count) events (filtered out \(beforeSearch - events.count))")
        }
        
        // Apply date/location filters
        let beforeFilter = events.count
        switch selectedFilter {
        case "Tonight":
            events = events.filter { event in
                guard let eventDateString = event.eventDate,
                      let eventDate = parseEventDate(eventDateString) else { 
                    print("⚠️ EVENTS: Filtering out event '\(event.eventName ?? "Unknown")' - no valid date")
                    return false 
                }
                return Calendar.current.isDateInToday(eventDate)
            }
            print("🌙 EVENTS: After 'Tonight' filter: \(events.count) events (filtered out \(beforeFilter - events.count))")
        case "This Week":
            events = events.filter { event in
                guard let eventDateString = event.eventDate,
                      let eventDate = parseEventDate(eventDateString) else { 
                    print("⚠️ EVENTS: Filtering out event '\(event.eventName ?? "Unknown")' - no valid date")
                    return false 
                }
                return Calendar.current.isDate(eventDate, equalTo: Date(), toGranularity: .weekOfYear)
            }
            print("📅 EVENTS: After 'This Week' filter: \(events.count) events (filtered out \(beforeFilter - events.count))")
        case "In City":
            events = applyInCityFilter(to: events)
            print("🏙️ EVENTS: After 'In City' filter: \(events.count) events (filtered out \(beforeFilter - events.count))")
        case "Nearby":
            events = applyNearbyFilter(to: events)
            print("📍 EVENTS: After 'Nearby' filter: \(events.count) events (filtered out \(beforeFilter - events.count))")
        default:
            print("🌐 EVENTS: 'All' filter: keeping all \(events.count) events")
        }
        
        // Filter out events without images
        let beforeImageFilter = events.count
        events = events.filter { event in
            let hasImage = event.imageURL != nil
            if !hasImage {
                print("🖼️ EVENTS: Filtering out event '\(event.eventName ?? event.venueName ?? "Unknown")' - no image available")
            }
            return hasImage
        }
        
        print("🖼️ EVENTS: After image filter: \(events.count) events (filtered out \(beforeImageFilter - events.count))")
        print("🎯 EVENTS: Final result: \(events.count) events")
        
        // Sort by recent check-ins (most popular first)
        return sortEventsByPopularity(events)
    }
    
    // MARK: - Location-based Filtering
    
    private func applyInCityFilter(to events: [FirebaseEvent]) -> [FirebaseEvent] {
        guard let currentUser = userSession.currentUser,
              let userCity = currentUser.city?.lowercased() else {
            print("📍 No user city available for filtering")
            return events
        }
        
        return events.filter { event in
            guard let eventCity = event.city?.lowercased() else {
                // If event has no city data, check location string
                if let location = event.eventLocation?.lowercased() {
                    return location.contains(userCity) || userCity.contains(location)
                }
                return false
            }
            return eventCity.contains(userCity) || userCity.contains(eventCity)
        }
    }
    
    private func applyNearbyFilter(to events: [FirebaseEvent]) -> [FirebaseEvent] {
        guard locationManager.hasLocationPermission,
              locationManager.location != nil else {
            print("📍 No location permission or location for nearby filtering")
            return events
        }
        
        return events.filter { event in
            guard let coordinates = event.coordinates else {
                print("📍 Event '\(event.name)' has no coordinates, including in nearby")
                return true // Include events without coordinates for now
            }
            
            // Check if event is within 25 miles for "Nearby" (more generous than check-in range)
            let distance = locationManager.distanceToEvent(coordinates)
            let maxNearbyDistance = 40233.6 // 25 miles in meters
            
            if let distance = distance {
                let isNearby = distance <= maxNearbyDistance
                let miles = distance * 0.000621371
                print("📍 Event '\(event.name)' is \(String(format: "%.1f", miles)) miles away, nearby: \(isNearby)")
                return isNearby
            }
            
            return true
        }
    }
    
    private func sortEventsByPopularity(_ events: [FirebaseEvent]) -> [FirebaseEvent] {
        // For now, return events as-is. This would be enhanced with cloud function data
        return events
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchAndFilterSection
                
                if eventsService.isLoading {
                    loadingSection
                } else if filteredEvents.isEmpty {
                    emptyStateSection
                } else {
                    eventsListSection
                }
            }
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                eventsService.refreshEvents()
            }
            .onAppear {
                eventsService.fetchEvents()
                // Request location permission if needed for nearby filtering
                if locationManager.needsLocationPermission {
                    locationManager.requestLocationPermission()
                }
            }
            .sheet(isPresented: $showLocationPermissionAlert) {
                LocationPermissionAlert(
                    isPresented: $showLocationPermissionAlert,
                    onRequestPermission: {
                        locationManager.requestLocationPermission()
                    },
                    onOpenSettings: {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                )
            }
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField("Search events, venues, or locations", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16))
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
                            title: filterDisplayName(filter),
                            isSelected: selectedFilter == filter
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                                handleFilterSelection(filter)
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
                    
                    // Location status indicator
                    if selectedFilter == "Nearby" {
                        locationStatusIndicator
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 12)
    }
    
    private var locationStatusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: locationManager.hasLocationPermission ? "location.fill" : "location.slash")
                .font(.caption)
                .foregroundColor(locationManager.hasLocationPermission ? .green : .orange)
            
            Text(locationManager.hasLocationPermission ? "Location enabled" : "Location needed")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func filterDisplayName(_ filter: String) -> String {
        switch filter {
        case "In City":
            if let city = userSession.currentUser?.city {
                return "In \(city)"
            }
            return "In City"
        default:
            return filter
        }
    }
    
    private func handleFilterSelection(_ filter: String) {
        if filter == "Nearby" && !locationManager.hasLocationPermission {
            if locationManager.locationDenied {
                showLocationPermissionAlert = true
            } else {
                locationManager.requestLocationPermission()
            }
        }
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
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Events Found")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(emptyStateMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if selectedFilter == "Nearby" && !locationManager.hasLocationPermission {
                Button("Enable Location") {
                    showLocationPermissionAlert = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case "Tonight":
            return "No events scheduled for tonight. Check back tomorrow!"
        case "This Week":
            return "No events scheduled for this week. Try expanding your search."
        case "In City":
            return "No events found in your city. Try the 'All' or 'Nearby' filters."
        case "Nearby":
            return locationManager.hasLocationPermission ? 
                "No events found within 25 miles of your location." :
                "Enable location services to find events near you."
        default:
            return "No events match your search criteria. Try adjusting your filters."
        }
    }
    
    private var eventsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredEvents, id: \.uniqueID) { event in
                    EventCardView(
                        event: event,
                        checkInsService: checkInsService,
                        onCardTap: {
                            selectedEvent = event
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 100) // Extra space at bottom
        }
    }
}

// MARK: - Enhanced Event Card View with Location Validation
struct EventCardView: View {
    let event: FirebaseEvent
    let checkInsService: FirebaseCheckInsService
    let onCardTap: () -> Void
    
    @State private var isCheckedIn = false
    @State private var isProcessing = false
    @State private var checkInCount = 0
    @State private var showLocationAlert = false
    @State private var locationError: String?
    @StateObject private var locationManager = LocationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image Header - Only this should be tappable for card navigation
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: event.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                } placeholder: {
                    eventImagePlaceholder
                }
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .contentShape(Rectangle()) // Ensure tap area is well-defined
                .onTapGesture {
                    print("🎯 Image tapped for event: \(event.name)")
                    onCardTap()
                }
                
                // Check-in count badge
                if checkInCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text("\(checkInCount)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(12)
                }
                
                // Distance indicator for events with coordinates
                if let coordinates = event.coordinates,
                   locationManager.hasLocationPermission,
                   let distance = locationManager.distanceToEvent(coordinates) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(locationManager.formattedDistance(to: coordinates))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(12)
                        }
                    }
                }
            }
            
            // Event Details - No tap gesture here
            VStack(spacing: 12) {
                // Event Info Section - Tappable area for navigation
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let venueName = event.venueName {
                        Text(venueName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let location = event.eventLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle()) // Ensure tap area is well-defined
                .onTapGesture {
                    print("🎯 Info section tapped for event: \(event.name)")
                    onCardTap()
                }
                
                // Enhanced Check-in Button with Location Validation
                Button(action: {
                    print("🎯 Check-in button tapped for event: \(event.name)")
                    toggleCheckIn()
                }) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: checkInButtonIcon)
                                .font(.subheadline)
                        }
                        Text(checkInButtonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isCheckedIn ? .white : .blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(checkInButtonBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCheckedIn ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                .buttonStyle(PlainButtonStyle()) // Prevents default button styling
                .contentShape(RoundedRectangle(cornerRadius: 20)) // Ensure button tap area is exclusive
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onAppear {
            checkIfUserCheckedIn()
            loadCheckInCount()
        }
        .alert("Location Required", isPresented: $showLocationAlert) {
            Button("Enable Location") {
                if locationManager.locationDenied {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                } else {
                    locationManager.requestLocationPermission()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(locationError ?? "Location access is required to check in to events. This helps verify you're actually at the location.")
        }
    }
    
    private var checkInButtonIcon: String {
        if isCheckedIn {
            return "checkmark.circle.fill"
        } else if event.coordinates != nil && locationManager.hasLocationPermission {
            return "location.circle"
        } else {
            return "plus.circle"
        }
    }
    
    private var checkInButtonText: String {
        if isProcessing {
            return "Processing..."
        } else if isCheckedIn {
            return "Check Out"
        } else if event.coordinates != nil {
            return "Check In"
        } else {
            return "Check In"
        }
    }
    
    private var checkInButtonBackground: some View {
        Group {
            if isCheckedIn {
                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            } else {
                LinearGradient(colors: [.blue.opacity(0.1), .blue.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
            }
        }
    }
    
    private var eventImagePlaceholder: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 200)
        .overlay(
            VStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.9))
                Text(event.name.prefix(20))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        )
    }
    
    private func toggleCheckIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else {
            print("❌ Missing user or event ID")
            return
        }
        
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            checkInsService.checkOut(userId: userId, eventId: eventId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = false
                        loadCheckInCount()
                        NotificationCenter.default.post(name: .checkInStatusChanged, object: nil)
                    } else {
                        print("❌ Check out failed: \(error ?? "Unknown error")")
                    }
                }
            }
        } else {
            // Check in with location validation
            checkInsService.checkInWithLocationValidation(
                userId: userId,
                eventId: eventId,
                event: event
            ) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = true
                        loadCheckInCount()
                        NotificationCenter.default.post(name: .checkInStatusChanged, object: nil)
                    } else {
                        locationError = error
                        showLocationAlert = true
                        print("❌ Check in failed: \(error ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else { return }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { [self] checkedIn in
            DispatchQueue.main.async {
                isCheckedIn = checkedIn
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let eventId = event.id else { return }
        
        checkInsService.getCheckInCount(for: eventId) { [self] count in
            DispatchQueue.main.async {
                checkInCount = count
            }
        }
    }
}

// MARK: - Image Cache
class ImageCache {
    static let shared = ImageCache()
    private init() {}
    
    private let cache = NSCache<NSString, UIImage>()
    
    func getImage(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: NSString(string: key))
    }
}

// MARK: - Helper Functions

// Extension for corner radius with specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

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

// MARK: - Enhanced Event Detail View
struct EventDetailView: View {
    let event: FirebaseEvent
    
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @State private var isCheckedIn = false
    @State private var isProcessing = false
    @State private var checkInCount = 0
    @State private var attendees: [FirebaseMember] = []
    @State private var isLoadingAttendees = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Event Image Header
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: event.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 300)
                                .clipped()
                        default:
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 300)
                            .overlay(
                                VStack {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("Event Image")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            )
                        }
                    }
                    
                    // Check-in count overlay
                    if checkInCount > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(checkInCount) attending")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(16)
                    }
                }
                
                // Event Details Section
                VStack(spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(event.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .lineLimit(3)
                        
                        if let venueName = event.venueName {
                            HStack(spacing: 8) {
                                Image(systemName: "building.2")
                                    .foregroundColor(.secondary)
                                Text(venueName)
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let location = event.eventLocation {
                            HStack(spacing: 8) {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Event Time
                        if let startTime = event.eventStartTime {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text(startTime)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                if let endTime = event.eventEndTime {
                                    Text("- \(endTime)")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Check-in Button
                    checkInButtonSection
                    
                    // Attendees Section - Show who's checked in
                    if !attendees.isEmpty || isLoadingAttendees {
                        attendeesSection
                    }
                    
                    // Additional Event Info Section (minimalist)
                    if hasAdditionalInfo {
                        additionalInfoSection
                    }
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupEventDetail()
        }
    }
    
    private var checkInButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: toggleCheckIn) {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.9)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                    }
                    
                    Text(getCheckInButtonText())
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isCheckedIn ? 
                            [Color.green, Color.green.opacity(0.8)] :
                            [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: isCheckedIn ? .green.opacity(0.3) : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing)
            .buttonStyle(PlainButtonStyle())
            
            if isCheckedIn {
                Text("You're checked in to this event!")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Who's Going")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if checkInCount > 0 {
                    Text("(\(checkInCount))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                if isLoadingAttendees {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            
            if attendees.isEmpty && !isLoadingAttendees {
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
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attendees, id: \.uniqueID) { member in
                            AttendeeCardView(member: member)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Additional Info Section
    
    private var hasAdditionalInfo: Bool {
        return event.eventCategory != nil || 
               event.isEventFree != nil || 
               event.eventDate != nil ||
               (event.eventStartTime != nil && event.eventEndTime != nil)
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Details")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                // Event Date & Time
                if let eventDate = event.eventDate {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Date")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(eventDate)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                // Time Range
                if let startTime = event.eventStartTime {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(startTime)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let endTime = event.eventEndTime {
                            Text("- \(endTime)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Spacer()
                    }
                }
                
                // Category
                if let category = event.eventCategory {
                    HStack(spacing: 8) {
                        Image(systemName: "tag")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        Text("Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(category)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                
                // Free Event Badge
                if let isFree = event.isEventFree, isFree {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Cost")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text("Free Event")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
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
        print("🔍 DEBUG: EventDetailView toggleCheckIn called")
        print("🔍 DEBUG: event.name = \(event.eventName ?? "nil")")
        print("🔍 DEBUG: event.id = \(event.id ?? "nil")")
        print("🔍 DEBUG: event.uniqueID = \(event.uniqueID)")
        print("🔍 DEBUG: currentUser = \(FirebaseUserSession.shared.currentUser?.firstName ?? "nil")")
        print("🔍 DEBUG: currentUser.id = \(FirebaseUserSession.shared.currentUser?.id ?? "nil")")
        print("🔍 DEBUG: CURRENT isCheckedIn = \(isCheckedIn)")
        print("🔍 DEBUG: CURRENT checkInCount = \(checkInCount)")
        print("🔍 DEBUG: CURRENT isProcessing = \(isProcessing)")
        
        guard let currentUser = FirebaseUserSession.shared.currentUser else {
            print("❌ Cannot check in: Missing user")
            return
        }
        
        // CRITICAL FIX: Use Firebase Auth UID, not Firestore document ID
        guard let firebaseAuthUser = FirebaseUserSession.shared.firebaseAuthUser else {
            print("❌ Cannot check in: Missing Firebase Auth UID")
            print("❌ Current user: \(currentUser.firstName ?? "nil")")
            print("❌ Firebase Auth user: \(FirebaseUserSession.shared.firebaseAuthUser?.email ?? "nil")")
            return
        }
        
        let firebaseAuthUID = firebaseAuthUser.uid
        print("🔧 USING Firebase Auth UID: \(firebaseAuthUID)")
        print("🔧 NOT using Firestore document ID: \(currentUser.id ?? "nil")")
        
        // Use event.id if available, otherwise use uniqueID as fallback
        let eventId = event.id ?? event.uniqueID
        guard !eventId.isEmpty else {
            print("❌ Cannot check in: Event has no valid ID")
            print("❌ event.id: \(event.id ?? "nil")")
            print("❌ event.uniqueID: \(event.uniqueID)")
            return
        }
        
        guard !isProcessing else { 
            print("⚠️ Check-in already in progress")
            return 
        }
        
        print("🎯 Starting check-in process for Firebase Auth UID \(firebaseAuthUID) at event \(eventId)")
        print("🎯 Current state - isCheckedIn: \(isCheckedIn), will \(isCheckedIn ? "CHECK OUT" : "CHECK IN")")
        Haptics.lightImpact()
        isProcessing = true
        print("🔍 Set isProcessing = true")
        
        if isCheckedIn {
            // Check out
            print("🔄 CHECKOUT: Starting check-out process...")
            checkInsService.checkOut(userId: firebaseAuthUID, eventId: eventId) { success, error in
                print("🔄 CHECKOUT: Firebase response received - success: \(success), error: \(error ?? "none")")
                DispatchQueue.main.async {
                    print("🔄 CHECKOUT: Processing response on main thread")
                    self.isProcessing = false
                    print("🔍 Set isProcessing = false")
                    if success {
                        print("✅ CHECKOUT: Success - updating UI state")
                        let oldCheckedIn = self.isCheckedIn
                        let oldCount = self.checkInCount
                        self.isCheckedIn = false
                        self.checkInCount = max(0, self.checkInCount - 1)
                        print("✅ CHECKOUT: State updated - isCheckedIn: \(oldCheckedIn) → \(self.isCheckedIn), checkInCount: \(oldCount) → \(self.checkInCount)")
                        Haptics.successNotification()
                        print("✅ Successfully checked out of event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": false]
                        )
                        print("📢 Posted checkInStatusChanged notification")
                    } else {
                        print("❌ CHECKOUT: Failed - \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in
            print("🔄 CHECKIN: Starting check-in process...")
            checkInsService.checkIn(userId: firebaseAuthUID, eventId: eventId) { success, error in
                print("🔄 CHECKIN: Firebase response received - success: \(success), error: \(error ?? "none")")
                DispatchQueue.main.async {
                    print("🔄 CHECKIN: Processing response on main thread")
                    self.isProcessing = false
                    print("🔍 Set isProcessing = false")
                    if success {
                        print("✅ CHECKIN: Success - updating UI state")
                        let oldCheckedIn = self.isCheckedIn
                        let oldCount = self.checkInCount
                        self.isCheckedIn = true
                        self.checkInCount += 1
                        print("✅ CHECKIN: State updated - isCheckedIn: \(oldCheckedIn) → \(self.isCheckedIn), checkInCount: \(oldCount) → \(self.checkInCount)")
                        Haptics.successNotification()
                        print("✅ Successfully checked in to event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": true]
                        )
                        print("📢 Posted checkInStatusChanged notification")
                    } else {
                        print("❌ CHECKIN: Failed - \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        print("🔍 INIT: EventDetailView checkIfUserCheckedIn called for event \(event.eventName ?? "unknown")")
        
        guard let currentUser = FirebaseUserSession.shared.currentUser else {
            print("⚠️ INIT: Cannot check user check-in status: Missing user")
            return
        }
        
        // CRITICAL FIX: Use Firebase Auth UID, not Firestore document ID
        guard let firebaseAuthUser = FirebaseUserSession.shared.firebaseAuthUser else {
            print("⚠️ INIT: Cannot check user check-in status: Missing Firebase Auth UID")
            print("⚠️ INIT: currentUser = \(currentUser.firstName ?? "nil")")
            print("⚠️ INIT: currentUser.id = \(currentUser.id ?? "nil")")
            print("⚠️ INIT: firebaseAuthUser = \(FirebaseUserSession.shared.firebaseAuthUser?.email ?? "nil")")
            return
        }
        
        let firebaseAuthUID = firebaseAuthUser.uid
        
        // Use event.id if available, otherwise use uniqueID as fallback
        let eventId = event.id ?? event.uniqueID
        guard !eventId.isEmpty else {
            print("⚠️ INIT: Cannot check user check-in status: Missing event ID")
            print("⚠️ INIT: event.id = \(event.id ?? "nil")")
            print("⚠️ INIT: event.uniqueID = \(event.uniqueID)")
            return
        }
        
        print("🔍 INIT: Checking check-in status for Firebase Auth UID=\(firebaseAuthUID), eventId=\(eventId)")
        
        checkInsService.isUserCheckedIn(userId: firebaseAuthUID, eventId: eventId) { isCheckedIn in
            print("🔍 INIT: isUserCheckedIn callback received with result: \(isCheckedIn)")
            DispatchQueue.main.async {
                print("🔍 INIT: Processing isUserCheckedIn result on main thread")
                let oldValue = self.isCheckedIn
                self.isCheckedIn = isCheckedIn
                print("📊 INIT: User check-in status loaded: \(oldValue) → \(self.isCheckedIn)")
            }
        }
    }
    
    private func loadCheckInCount() {
        print("🔍 INIT: loadCheckInCount called for event \(event.eventName ?? "unknown")")
        
        // Use event.id if available, otherwise use uniqueID as fallback
        let eventId = event.id ?? event.uniqueID
        guard !eventId.isEmpty else {
            print("⚠️ INIT: Cannot load check-in count: Missing event ID")
            print("⚠️ INIT: event.id = \(event.id ?? "nil")")
            print("⚠️ INIT: event.uniqueID = \(event.uniqueID)")
            return
        }
        
        print("🔍 INIT: Loading check-in count for eventId=\(eventId)")
        
        checkInsService.getCheckInCount(for: eventId) { count in
            print("🔍 INIT: getCheckInCount callback received with result: \(count)")
            DispatchQueue.main.async {
                print("🔍 INIT: Processing getCheckInCount result on main thread")
                let oldValue = self.checkInCount
                self.checkInCount = count
                print("📊 INIT: Check-in count loaded: \(oldValue) → \(self.checkInCount)")
            }
        }
    }
    
    private func loadAttendees() {
        // Use event.id if available, otherwise use uniqueID as fallback
        let eventId = event.id ?? event.uniqueID
        guard !eventId.isEmpty else {
            print("⚠️ Cannot load attendees: Missing event ID")
            return
        }
        
        isLoadingAttendees = true
        checkInsService.getMembersAtEvent(eventId) { members in
            DispatchQueue.main.async {
                self.attendees = members
                self.isLoadingAttendees = false
                print("👥 Loaded \(members.count) attendees")
            }
        }
    }
    
    private func getCheckInButtonText() -> String {
        if isProcessing {
            return isCheckedIn ? "Checking Out..." : "Checking In..."
        } else {
            return isCheckedIn ? "Check Out" : "Check In to Event"
        }
    }
}

// MARK: - Attendee Card View
struct AttendeeCardView: View {
    let member: FirebaseMember
    
    var body: some View {
        VStack(spacing: 8) {
            // Profile Image
            CachedAsyncImage(url: member.profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(member.firstName.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }
            
            // Member Info
            VStack(spacing: 2) {
                Text(member.firstName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if let age = member.age {
                    Text("\(age)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let city = member.city {
                    Text(city)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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

#Preview {
    CheckInsView()
}



// MARK: - Helper Functions
extension CheckInsView {
    private func parseEventDate(_ dateString: String) -> Date? {
        let formatters = [
            DateFormatter().with { $0.dateFormat = "yyyy-MM-dd" },
            DateFormatter().with { $0.dateFormat = "MM/dd/yyyy" },
            DateFormatter().with { $0.dateFormat = "dd/MM/yyyy" }
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }
}

extension DateFormatter {
    func with(_ configurator: (DateFormatter) -> Void) -> DateFormatter {
        configurator(self)
        return self
    }
} 