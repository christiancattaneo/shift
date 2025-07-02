import SwiftUI
import Combine
import CoreLocation

// MARK: - Notification Extensions
extension Notification.Name {
    static let checkInStatusChanged = Notification.Name("checkInStatusChanged")
}

// MARK: - Main CheckInsView
struct CheckInsView: View {
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedContentType: ContentType = .events
    @State private var selectedEvent: FirebaseEvent? = nil
    @State private var selectedPlace: FirebasePlace? = nil
    @State private var showLocationPermissionAlert = false
    @State private var recentlyCheckedInEventIds: Set<String> = []
    @State private var recentlyCheckedInPlaceIds: Set<String> = []
    @StateObject private var eventsService = FirebaseEventsService()
    @StateObject private var placesService = FirebasePlacesService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var userSession = FirebaseUserSession.shared
    
    private let filters = ["All", "Tonight", "This Week", "In City", "Nearby"]
    
    enum ContentType: String, CaseIterable {
        case events = "Events"
        case places = "Places"
    }
    
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
        
        // Sort by recent check-ins (most popular first), but prioritize recently checked-in events
        let sortedEvents = sortEventsByPopularity(events)
        return prioritizeRecentlyCheckedInEvents(sortedEvents)
    }
    
    var filteredPlaces: [FirebasePlace] {
        var places = placesService.places
        print("🎯 PLACES: Starting with \(places.count) total places from service")
        
        // Apply search filter
        if !searchText.isEmpty {
            let beforeSearch = places.count
            places = places.filter { place in
                (place.placeName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (place.placeLocation?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (place.address?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
            print("🔍 PLACES: After search '\(searchText)': \(places.count) places (filtered out \(beforeSearch - places.count))")
        }
        
        // Apply location filters
        let beforeFilter = places.count
        switch selectedFilter {
        case "In City":
            places = applyInCityFilterToPlaces(to: places)
            print("🏙️ PLACES: After 'In City' filter: \(places.count) places (filtered out \(beforeFilter - places.count))")
        case "Nearby":
            places = applyNearbyFilterToPlaces(to: places)
            print("📍 PLACES: After 'Nearby' filter: \(places.count) places (filtered out \(beforeFilter - places.count))")
        default:
            print("🌐 PLACES: 'All' filter: keeping all \(places.count) places")
        }
        
        // Filter out places without names or images
        places = places.filter { place in
            let hasName = !(place.placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            if !hasName {
                print("🏷️ PLACES: Filtering out place with no name")
            }
            return hasName
        }
        
        let beforeImageFilter = places.count
        places = places.filter { place in
            let hasImage = place.imageURL != nil
            if !hasImage {
                print("🖼️ PLACES: Filtering out place '\(place.placeName ?? "Unknown")' - no image available")
            }
            return hasImage
        }
        
        print("🖼️ PLACES: After image filter: \(places.count) places (filtered out \(beforeImageFilter - places.count))")
        print("🎯 PLACES: Final result: \(places.count) places")
        
        // Sort by popularity, but prioritize recently checked-in places
        let sortedPlaces = sortPlacesByPopularity(places)
        return prioritizeRecentlyCheckedInPlaces(sortedPlaces)
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
        return events.sorted { event1, event2 in
            // Priority 1: Most recent check-ins (last 24 hours)
            let recent1 = event1.recentCheckIns ?? 0
            let recent2 = event2.recentCheckIns ?? 0
            if recent1 != recent2 {
                return recent1 > recent2
            }
            
            // Priority 2: Overall popularity score
            let score1 = event1.popularityScore ?? 0
            let score2 = event2.popularityScore ?? 0
            if score1 != score2 {
                return score1 > score2
            }
            
            // Priority 3: Weekly check-ins
            let weekly1 = event1.weeklyCheckIns ?? 0
            let weekly2 = event2.weeklyCheckIns ?? 0
            if weekly1 != weekly2 {
                return weekly1 > weekly2
            }
            
            // Priority 4: Total check-ins
            let total1 = event1.totalCheckIns ?? 0
            let total2 = event2.totalCheckIns ?? 0
            if total1 != total2 {
                return total1 > total2
            }
            
            // Priority 5: Most recently created
            let created1 = event1.createdAt?.dateValue() ?? Date.distantPast
            let created2 = event2.createdAt?.dateValue() ?? Date.distantPast
            return created1 > created2
        }
    }
    
    // MARK: - Places Location Filtering
    
    private func applyInCityFilterToPlaces(to places: [FirebasePlace]) -> [FirebasePlace] {
        guard let currentUser = userSession.currentUser,
              let userCity = currentUser.city?.lowercased() else {
            print("📍 No user city available for filtering places")
            return places
        }

        return places.filter { place in
            guard let placeCity = place.city?.lowercased() else {
                // If place has no city data, check location string
                if let location = place.placeLocation?.lowercased() {
                    return location.contains(userCity) || userCity.contains(location)
                }
                return false
            }
            return placeCity.contains(userCity) || userCity.contains(placeCity)
        }
    }
    
    private func applyNearbyFilterToPlaces(to places: [FirebasePlace]) -> [FirebasePlace] {
        guard locationManager.hasLocationPermission,
              locationManager.location != nil else {
            print("📍 No location permission or location for nearby filtering places")
            return places
        }
        
        return places.filter { place in
            guard let coordinates = place.coordinates else {
                print("📍 Place '\(place.name)' has no coordinates, including in nearby")
                return true // Include places without coordinates for now
            }
            
            // Check if place is within 25 miles for "Nearby" (more generous than check-in range)
            let distance = locationManager.distanceToEvent(coordinates)
            let maxNearbyDistance = 40233.6 // 25 miles in meters
            
            if let distance = distance {
                let isNearby = distance <= maxNearbyDistance
                let miles = distance * 0.000621371
                print("📍 Place '\(place.name)' is \(String(format: "%.1f", miles)) miles away, nearby: \(isNearby)")
                return isNearby
            }
            
            return true
        }
    }
    
    private func sortPlacesByPopularity(_ places: [FirebasePlace]) -> [FirebasePlace] {
        return places.sorted { place1, place2 in
            // Priority 1: Most recent check-ins (last 24 hours)
            let recent1 = place1.recentCheckIns ?? 0
            let recent2 = place2.recentCheckIns ?? 0
            if recent1 != recent2 {
                return recent1 > recent2
            }
            
            // Priority 2: Overall popularity score
            let score1 = place1.popularityScore ?? 0
            let score2 = place2.popularityScore ?? 0
            if score1 != score2 {
                return score1 > score2
            }
            
            // Priority 3: Weekly check-ins
            let weekly1 = place1.weeklyCheckIns ?? 0
            let weekly2 = place2.weeklyCheckIns ?? 0
            if weekly1 != weekly2 {
                return weekly1 > weekly2
            }
            
            // Priority 4: Total check-ins
            let total1 = place1.totalCheckIns ?? 0
            let total2 = place2.totalCheckIns ?? 0
            if total1 != total2 {
                return total1 > total2
            }
            
            // Priority 5: Most recently created
            let created1 = place1.createdAt?.dateValue() ?? Date.distantPast
            let created2 = place2.createdAt?.dateValue() ?? Date.distantPast
            return created1 > created2
        }
    }
    
    // MARK: - Recently Checked-In Prioritization
    
    private func prioritizeRecentlyCheckedInEvents(_ events: [FirebaseEvent]) -> [FirebaseEvent] {
        let recentlyCheckedIn = events.filter { event in
            recentlyCheckedInEventIds.contains(event.id ?? event.uniqueID)
        }
        let others = events.filter { event in
            !recentlyCheckedInEventIds.contains(event.id ?? event.uniqueID)
        }
        
        print("🎯 PRIORITY: Moving \(recentlyCheckedIn.count) recently checked-in events to top")
        return recentlyCheckedIn + others
    }
    
    private func prioritizeRecentlyCheckedInPlaces(_ places: [FirebasePlace]) -> [FirebasePlace] {
        let recentlyCheckedIn = places.filter { place in
            recentlyCheckedInPlaceIds.contains(place.id ?? "")
        }
        let others = places.filter { place in
            !recentlyCheckedInPlaceIds.contains(place.id ?? "")
        }
        
        print("🎯 PRIORITY: Moving \(recentlyCheckedIn.count) recently checked-in places to top")
        return recentlyCheckedIn + others
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom Header with Title and Toggle
            customHeaderSection
            
            // Content Section
            if (selectedContentType == .events && eventsService.isLoading) || 
               (selectedContentType == .places && placesService.isLoading) {
                loadingSection
            } else if (selectedContentType == .events && filteredEvents.isEmpty) || 
                      (selectedContentType == .places && filteredPlaces.isEmpty) {
                emptyStateSection
            } else {
                contentListSection
                    }
            }
        .refreshable {
            // Clear prioritization on refresh to show latest data order
            recentlyCheckedInEventIds.removeAll()
            recentlyCheckedInPlaceIds.removeAll()
            print("🎯 PRIORITY: Cleared prioritization lists due to refresh")
            
            if selectedContentType == .events {
                eventsService.refreshEvents()
            } else {
                placesService.refreshPlaces()
            }
        }
        .onAppear {
                eventsService.fetchEvents()
            placesService.fetchPlaces()
                // Request location permission if needed for nearby filtering
                if locationManager.needsLocationPermission {
                    locationManager.requestLocationPermission()
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: .checkInStatusChanged)) { notification in
            // Listen for check-in status changes and prioritize checked-in items
            guard let userInfo = notification.userInfo else { return }
            
            if let eventId = userInfo["eventId"] as? String,
               let isCheckedIn = userInfo["isCheckedIn"] as? Bool {
                print("🎯 CHECKINS: Received event check-in notification - eventId: \(eventId), isCheckedIn: \(isCheckedIn)")
                
                if isCheckedIn {
                    // Add to recently checked-in events (move to top)
                    recentlyCheckedInEventIds.insert(eventId)
                    print("🎯 PRIORITY: Added event \(eventId) to priority list")
                    
                    // Auto-remove from priority list after 30 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        recentlyCheckedInEventIds.remove(eventId)
                        print("🎯 PRIORITY: Auto-removed event \(eventId) from priority list after 30s")
                    }
                } else {
                    // Remove from recently checked-in events
                    recentlyCheckedInEventIds.remove(eventId)
                    print("🎯 PRIORITY: Removed event \(eventId) from priority list")
                }
            }
            
            if let placeId = userInfo["placeId"] as? String,
               let isCheckedIn = userInfo["isCheckedIn"] as? Bool {
                print("🎯 CHECKINS: Received place check-in notification - placeId: \(placeId), isCheckedIn: \(isCheckedIn)")
                
                if isCheckedIn {
                    // Add to recently checked-in places (move to top)
                    recentlyCheckedInPlaceIds.insert(placeId)
                    print("🎯 PRIORITY: Added place \(placeId) to priority list")
                    
                    // Auto-remove from priority list after 30 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                        recentlyCheckedInPlaceIds.remove(placeId)
                        print("🎯 PRIORITY: Auto-removed place \(placeId) from priority list after 30s")
                    }
                } else {
                    // Remove from recently checked-in places
                    recentlyCheckedInPlaceIds.remove(placeId)
                    print("🎯 PRIORITY: Removed place \(placeId) from priority list")
                }
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
        .sheet(item: $selectedEvent) { event in
            EventDetailView(event: event)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
        }
    }
    
    // MARK: - Custom Header Section
    private var customHeaderSection: some View {
        VStack(spacing: 0) {
            // Title Section
            HStack {
                Text("Check Ins")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Content Type Toggle
            contentTypeToggle
            
            // Search and Filter Section
            searchAndFilterSection
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content Type Toggle
    private var contentTypeToggle: some View {
        HStack(spacing: 0) {
            ForEach(ContentType.allCases, id: \.self) { contentType in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedContentType = contentType
                        // Clear prioritization when switching content types
                        recentlyCheckedInEventIds.removeAll()
                        recentlyCheckedInPlaceIds.removeAll()
                        print("🎯 PRIORITY: Cleared prioritization lists due to content type change")
                    }
                }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: contentType == .events ? "calendar" : "location")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text(contentType.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(selectedContentType == contentType ? .white : .primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedContentType == contentType ?
                                AnyView(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                ) :
                                AnyView(Color.clear)
                        )
                        .cornerRadius(12)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
                
                TextField(selectedContentType == .events ? "Search events, venues, or locations" : "Search places, locations, or addresses", text: $searchText)
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
            if (selectedContentType == .events && !filteredEvents.isEmpty) || 
               (selectedContentType == .places && !filteredPlaces.isEmpty) {
                HStack {
                    let count = selectedContentType == .events ? filteredEvents.count : filteredPlaces.count
                    let itemType = selectedContentType == .events ? "events" : "places"
                    
                    Text("\(count) \(itemType)")
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
        .padding(.bottom, 8)
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
        let itemType = selectedContentType == .events ? "events" : "places"
        
        switch selectedFilter {
        case "Tonight":
            return selectedContentType == .events ? 
                "No events scheduled for tonight. Check back tomorrow!" :
                "Tonight filter only applies to events. Try switching to Events or use a different filter."
        case "This Week":
            return selectedContentType == .events ? 
                "No events scheduled for this week. Try expanding your search." :
                "This Week filter only applies to events. Try switching to Events or use a different filter."
        case "In City":
            return "No \(itemType) found in your city. Try the 'All' or 'Nearby' filters."
        case "Nearby":
            return locationManager.hasLocationPermission ? 
                "No \(itemType) found within 25 miles of your location." :
                "Enable location services to find \(itemType) near you."
        default:
            return "No \(itemType) match your search criteria. Try adjusting your filters."
        }
    }
    
    private var contentListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if selectedContentType == .events {
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
                } else {
                    ForEach(filteredPlaces, id: \.id) { place in
                        PlaceCardView(
                            place: place,
                            checkInsService: checkInsService,
                            onCardTap: {
                                selectedPlace = place
                            }
                        )
                        .padding(.horizontal, 20)
                    }
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
                        .frame(height: 300)
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
                
                // Check-in count badge - always show count
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
                
                // Distance indicator for events with coordinates
                if let coordinates = event.coordinates,
                   locationManager.hasLocationPermission,
                   let _ = locationManager.distanceToEvent(coordinates) {
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
        .onReceive(NotificationCenter.default.publisher(for: .checkInStatusChanged)) { notification in
            // Check if this notification is for our event
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String,
               let isCheckedIn = userInfo["isCheckedIn"] as? Bool,
               eventId == (event.id ?? event.uniqueID) {
                print("🔄 EventCard: Received check-in status change for event \(event.name): \(isCheckedIn)")
                DispatchQueue.main.async {
                    let wasCheckedIn = self.isCheckedIn
                    self.isCheckedIn = isCheckedIn
                    
                    // Update count immediately based on state change
                    if isCheckedIn && !wasCheckedIn {
                        self.checkInCount += 1
                    } else if !isCheckedIn && wasCheckedIn {
                        self.checkInCount = max(0, self.checkInCount - 1)
                    }
                    
                    // Then refresh from server for accuracy
                    self.loadCheckInCount()
                }
            }
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
            .frame(height: 300)
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
        print("🎯 EventCard: toggleCheckIn called for event: \(event.name)")
        
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else {
            print("❌ EventCard: Missing user or user ID")
            return
        }
        
        // Improved event ID resolution
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else {
            print("❌ EventCard: Event has no valid ID")
            return
        }
        
        print("🎯 EventCard: Using userId=\(userId), eventId=\(eventId)")
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            print("🔄 EventCard: Checking out...")
            checkInsService.checkOut(userId: userId, eventId: eventId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        print("✅ EventCard: Check out successful")
                        isCheckedIn = false
                        loadCheckInCount()
                        Haptics.successNotification()
                        let notificationData = ["eventId": eventId, "isCheckedIn": false] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 EventCard: Posted check-out notification for eventId: \(eventId)")
                    } else {
                        print("❌ EventCard: Check out failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in - use basic check-in for consistency with detail view
            print("🔄 EventCard: Checking in...")
            checkInsService.checkIn(userId: userId, eventId: eventId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        print("✅ EventCard: Check in successful")
                        isCheckedIn = true
                        loadCheckInCount()
                        Haptics.successNotification()
                        let notificationData = ["eventId": eventId, "isCheckedIn": true] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 EventCard: Posted check-in notification for eventId: \(eventId)")
                    } else {
                        print("❌ EventCard: Check in failed: \(error ?? "Unknown error")")
                        locationError = error
                        showLocationAlert = true
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else { return }
        
        // Use same event ID resolution as toggleCheckIn
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else { return }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { [self] checkedIn in
            DispatchQueue.main.async {
                isCheckedIn = checkedIn
            }
        }
    }
    
    private func loadCheckInCount() {
        // Use same event ID resolution as toggleCheckIn
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else { return }
        
        // ENHANCED: Get both current and historical check-in counts
        checkInsService.getCombinedCheckInCount(for: eventId, itemType: "event") { [self] currentCount, historicalCount in
            DispatchQueue.main.async {
                checkInCount = historicalCount  // Show TOTAL historical count instead of just current
                print("📊 EVENT: \(event.eventName ?? "Unknown") - Current: \(currentCount), Historical: \(historicalCount), SHOWING: \(historicalCount)")
            }
        }
    }
}

// MARK: - Place Card View
struct PlaceCardView: View {
    let place: FirebasePlace
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
            // Place Image Header
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(url: place.imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipped()
                } placeholder: {
                    placeImagePlaceholder
                }
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .contentShape(Rectangle())
                .onTapGesture {
                    print("🎯 Place image tapped for: \(place.name)")
                    onCardTap()
                }
                
                // Check-in count badge - always show count
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
                
                // Distance indicator for places with coordinates
                if let coordinates = place.coordinates,
                   locationManager.hasLocationPermission,
                   let _ = locationManager.distanceToEvent(coordinates) {
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
            
            // Place Details
            VStack(spacing: 12) {
                // Place Info Section
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let location = place.placeLocation {
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
                    
                    if let isFree = place.isPlaceFree, isFree {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Free to visit")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    print("🎯 Place info tapped for: \(place.name)")
                    onCardTap()
                }
                
                // Check-in Button
                Button(action: {
                    print("🎯 Check-in button tapped for place: \(place.name)")
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
                    .foregroundColor(isCheckedIn ? .white : .green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(checkInButtonBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCheckedIn ? Color.clear : Color.green.opacity(0.3), lineWidth: 1)
                    )
                }
                .disabled(isProcessing)
                .buttonStyle(PlainButtonStyle())
                .contentShape(RoundedRectangle(cornerRadius: 20))
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
        .onReceive(NotificationCenter.default.publisher(for: .checkInStatusChanged)) { notification in
            // Check if this notification is for our place
            if let userInfo = notification.userInfo,
               let placeId = userInfo["placeId"] as? String,
               let isCheckedIn = userInfo["isCheckedIn"] as? Bool,
               placeId == place.id {
                print("🔄 PlaceCard: Received check-in status change for place \(place.name): \(isCheckedIn)")
                DispatchQueue.main.async {
                    let wasCheckedIn = self.isCheckedIn
                    self.isCheckedIn = isCheckedIn
                    
                    // Update count immediately based on state change
                    if isCheckedIn && !wasCheckedIn {
                        self.checkInCount += 1
                    } else if !isCheckedIn && wasCheckedIn {
                        self.checkInCount = max(0, self.checkInCount - 1)
                    }
                    
                    // Then refresh from server for accuracy
                    self.loadCheckInCount()
                }
            }
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
            Text(locationError ?? "Location access is required to check in to places. This helps verify you're actually at the location.")
        }
    }
    
    private var checkInButtonIcon: String {
        if isCheckedIn {
            return "checkmark.circle.fill"
        } else if place.coordinates != nil && locationManager.hasLocationPermission {
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
        } else {
            return "Check In"
        }
    }
    
    private var checkInButtonBackground: some View {
        Group {
            if isCheckedIn {
                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
            } else {
                LinearGradient(colors: [.green.opacity(0.1), .green.opacity(0.05)], startPoint: .leading, endPoint: .trailing)
            }
        }
    }
    
    private var placeImagePlaceholder: some View {
        LinearGradient(
            colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 300)
        .overlay(
            VStack {
                Image(systemName: "location.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.9))
                Text(place.name.prefix(20))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        )
    }
    
    private func toggleCheckIn() {
        guard let firebaseAuthUser = FirebaseUserSession.shared.firebaseAuthUser,
              let placeId = place.id else {
            print("❌ Missing user or place ID")
            return
        }
        
        let firebaseAuthUID = firebaseAuthUser.uid
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            checkInsService.checkOut(userId: firebaseAuthUID, eventId: placeId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = false
                        loadCheckInCount()
                        let notificationData = ["placeId": placeId, "isCheckedIn": false] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 PlaceCard: Posted check-out notification for placeId: \(placeId)")
                    } else {
                        print("❌ Place check out failed: \(error ?? "Unknown error")")
                    }
                }
            }
        } else {
            // Check in
            checkInsService.checkIn(userId: firebaseAuthUID, eventId: placeId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = true
                        loadCheckInCount()
                        let notificationData = ["placeId": placeId, "isCheckedIn": true] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 PlaceCard: Posted check-in notification for placeId: \(placeId)")
                    } else {
                        locationError = error
                        showLocationAlert = true
                        print("❌ Place check in failed: \(error ?? "Unknown error")")
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let firebaseAuthUser = FirebaseUserSession.shared.firebaseAuthUser,
              let placeId = place.id else { return }
        
        let firebaseAuthUID = firebaseAuthUser.uid
        
        checkInsService.isUserCheckedIn(userId: firebaseAuthUID, eventId: placeId) { [self] checkedIn in
            DispatchQueue.main.async {
                isCheckedIn = checkedIn
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let placeId = place.id else { return }
        
        // ENHANCED: Get both current and historical check-in counts  
        checkInsService.getCombinedCheckInCount(for: placeId, itemType: "place") { [self] currentCount, historicalCount in
            DispatchQueue.main.async {
                checkInCount = historicalCount  // Show TOTAL historical count instead of just current
                print("📊 PLACE: \(place.placeName ?? "Unknown") - Current: \(currentCount), Historical: \(historicalCount), SHOWING: \(historicalCount)")
            }
        }
    }
}

// MARK: - Place Detail View
struct PlaceDetailView: View {
    let place: FirebasePlace
    
    @StateObject private var checkInsService = FirebaseCheckInsService()
    @State private var isCheckedIn = false
    @State private var isProcessing = false
    @State private var checkInCount = 0
    @State private var attendees: [FirebaseMember] = []
    @State private var isLoadingAttendees = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Place Image Header
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: place.imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 300)
                                .clipped()
                        default:
                            LinearGradient(
                                colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 300)
                            .overlay(
                                VStack {
                                    Image(systemName: "location.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("Place Image")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            )
                        }
                    }
                    
                    // Check-in count overlay - always show
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                        Text("\(checkInCount) been here")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(16)
                }
                
                // Place Details Section
                VStack(spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(place.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .lineLimit(3)
                        
                        if let location = place.placeLocation {
                            HStack(spacing: 8) {
                                Image(systemName: "location")
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let isFree = place.isPlaceFree, isFree {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Free to visit")
                                    .font(.body)
                                    .foregroundColor(.green)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Check-in Button
                    checkInButtonSection
                    
                    // Attendees Section - Always show who's ever been here
                    attendeesSection
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupPlaceDetail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .checkInStatusChanged)) { notification in
            // Update local state and reload attendees when check-in status changes
            if let userInfo = notification.userInfo,
               let placeId = userInfo["placeId"] as? String,
               let newIsCheckedIn = userInfo["isCheckedIn"] as? Bool,
               placeId == place.id {
                print("🔄 PlaceDetail: Received check-in status change - placeId: \(placeId), newStatus: \(newIsCheckedIn)")
                
                DispatchQueue.main.async {
                    // Store old value before updating
                    let wasCheckedIn = self.isCheckedIn
                    let oldCount = self.checkInCount
                    
                    // Update local check-in status immediately for responsive UI
                    self.isCheckedIn = newIsCheckedIn
                    
                    // Update check-in count based on state change
                    if newIsCheckedIn && !wasCheckedIn {
                        self.checkInCount += 1
                    } else if !newIsCheckedIn && wasCheckedIn {
                        self.checkInCount = max(0, self.checkInCount - 1)
                    }
                    
                    print("🔄 PlaceDetail: Updated local state immediately - isCheckedIn: \(wasCheckedIn) → \(self.isCheckedIn), count: \(oldCount) → \(self.checkInCount)")
                    
                    // Trigger Firebase update if needed and reload from server for accuracy
                    if !self.isProcessing {
                        self.loadAttendees()
                        self.loadCheckInCount()
                    }
                }
            }
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
                            [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing)
            .buttonStyle(PlainButtonStyle())
            
            if isCheckedIn {
                Text("You're checked in to this place!")
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
                Text("Who's Been Here")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("(\(checkInCount))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Spacer()
                
                if isLoadingAttendees {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)
            
            // Current User Card - Show prominently when checked in
            if isCheckedIn, let currentUser = FirebaseUserSession.shared.currentUser {
                CurrentUserMemberCard(user: currentUser, type: "place")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
            }
            
            // Check-in status message
            if !attendees.isEmpty || isCheckedIn {
                HStack(spacing: 8) {
                    Image(systemName: isCheckedIn ? "eye" : "eye.slash")
                        .font(.caption)
                        .foregroundColor(isCheckedIn ? .green : .orange)
                    
                    Text(isCheckedIn ? 
                         "You can see who's been here because you're checked in" : 
                         "Check in to see who else has been here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
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
                    HStack(spacing: 16) {
                        ForEach(attendees, id: \.uniqueID) { member in
                            AttendeeCardView(member: member, currentUserCheckedIn: isCheckedIn)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.top, 20)
    }
    
    private func setupPlaceDetail() {
        checkIfUserCheckedIn()
        loadCheckInCount()
        loadAttendees()
    }
    
    private func toggleCheckIn() {
        guard let firebaseAuthUser = FirebaseUserSession.shared.firebaseAuthUser,
              let placeId = place.id else {
            print("❌ Cannot check in: Missing Firebase Auth UID or place ID")
            return
        }
        
        let firebaseAuthUID = firebaseAuthUser.uid
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            checkInsService.checkOut(userId: firebaseAuthUID, eventId: placeId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = false
                        checkInCount = max(0, checkInCount - 1)
                        Haptics.successNotification()
                        let notificationData = ["placeId": placeId, "isCheckedIn": false] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 PlaceDetail: Posted check-out notification for placeId: \(placeId)")
                    } else {
                        print("❌ Place check out failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in
            checkInsService.checkIn(userId: firebaseAuthUID, eventId: placeId) { [self] success, error in
                DispatchQueue.main.async {
                    isProcessing = false
                    if success {
                        isCheckedIn = true
                        checkInCount += 1
                        Haptics.successNotification()
                        let notificationData = ["placeId": placeId, "isCheckedIn": true] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged, 
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 PlaceDetail: Posted check-in notification for placeId: \(placeId)")
                    } else {
                        print("❌ Place check in failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userUUID = currentUser.id,
              let placeId = place.id else { return }
        
        let userIdForCheckIn = userUUID
        
        checkInsService.isUserCheckedIn(userId: userIdForCheckIn, eventId: placeId) { isCheckedIn in
            DispatchQueue.main.async {
                self.isCheckedIn = isCheckedIn
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let placeId = place.id else { return }
        
        // ENHANCED: Get both current and historical check-in counts
        checkInsService.getCombinedCheckInCount(for: placeId, itemType: "place") { currentCount, historicalCount in
            DispatchQueue.main.async {
                self.checkInCount = historicalCount  // Show TOTAL historical count instead of just current
                print("📊 PLACE DETAIL: \(self.place.placeName ?? "Unknown") - Current: \(currentCount), Historical: \(historicalCount), SHOWING: \(historicalCount)")
            }
        }
    }
    
    private func loadAttendees() {
        guard let placeId = place.id else { return }
        
        isLoadingAttendees = true
        checkInsService.getMembersAtPlace(placeId) { members in
            DispatchQueue.main.async {
                self.attendees = members
                self.isLoadingAttendees = false
            }
        }
    }
    
    private func getCheckInButtonText() -> String {
        if isProcessing {
            return isCheckedIn ? "Checking Out..." : "Checking In..."
        } else {
            return isCheckedIn ? "Check Out" : "Check In to Place"
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
                    
                    // Check-in count overlay - always show
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
                    
                    // Attendees Section - Always show who's ever been here
                    attendeesSection
                    
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
        .onReceive(NotificationCenter.default.publisher(for: .checkInStatusChanged)) { notification in
            // Update local state and reload attendees when check-in status changes
            if let userInfo = notification.userInfo,
               let eventId = userInfo["eventId"] as? String,
               let newIsCheckedIn = userInfo["isCheckedIn"] as? Bool,
               eventId == (event.id ?? event.uniqueID) {
                print("🔄 EventDetail: Received check-in status change - eventId: \(eventId), newStatus: \(newIsCheckedIn)")
                
                DispatchQueue.main.async {
                    // Store old value before updating
                    let wasCheckedIn = self.isCheckedIn
                    let oldCount = self.checkInCount
                    
                    // Update local check-in status immediately for responsive UI
                    self.isCheckedIn = newIsCheckedIn
                    
                    // Update check-in count based on state change
                    if newIsCheckedIn && !wasCheckedIn {
                        self.checkInCount += 1
                    } else if !newIsCheckedIn && wasCheckedIn {
                        self.checkInCount = max(0, self.checkInCount - 1)
                    }
                    
                    print("🔄 EventDetail: Updated local state immediately - isCheckedIn: \(wasCheckedIn) → \(self.isCheckedIn), count: \(oldCount) → \(self.checkInCount)")
                    
                    // Trigger Firebase update if needed and reload from server for accuracy
                    if !self.isProcessing {
                        self.loadAttendees()
                        self.loadCheckInCount()
                    }
                }
            }
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
            .padding(.horizontal, 20)
            
            // Current User Card - Show prominently when checked in
            if isCheckedIn, let currentUser = FirebaseUserSession.shared.currentUser {
                CurrentUserMemberCard(user: currentUser, type: "event")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 20)
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
                .padding(.horizontal, 20)
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
                    HStack(spacing: 16) {
                        ForEach(attendees, id: \.uniqueID) { member in
                            AttendeeCardView(member: member, currentUserCheckedIn: isCheckedIn)
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
        print("🎯 EventDetail: toggleCheckIn called for event: \(event.eventName ?? "Unknown")")
        
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else {
            print("❌ EventDetail: Missing user or user ID")
            return
        }
        
        // Improved event ID resolution - same as EventCardView
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else {
            print("❌ EventDetail: Event has no valid ID")
            return
        }
        
        guard !isProcessing else { 
            print("⚠️ EventDetail: Check-in already in progress")
            return 
        }
        
        print("🎯 EventDetail: Using userId=\(userId), eventId=\(eventId)")
        print("🎯 EventDetail: Current state - isCheckedIn: \(isCheckedIn), will \(isCheckedIn ? "CHECK OUT" : "CHECK IN")")
        
        Haptics.lightImpact()
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            print("🔄 EventDetail: Checking out...")
            checkInsService.checkOut(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        print("✅ EventDetail: Check out successful")
                        self.isCheckedIn = false
                        self.checkInCount = max(0, self.checkInCount - 1)
                        Haptics.successNotification()
                        
                        // Notify other views about check-in status change
                        let notificationData = ["eventId": eventId, "isCheckedIn": false] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 EventDetail: Posted check-out notification for eventId: \(eventId)")
                    } else {
                        print("❌ EventDetail: Check out failed - \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in
            print("🔄 EventDetail: Checking in...")
            checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        print("✅ EventDetail: Check in successful")
                        self.isCheckedIn = true
                        self.checkInCount += 1
                        Haptics.successNotification()
                        
                        // Notify other views about check-in status change
                        let notificationData = ["eventId": eventId, "isCheckedIn": true] as [String : Any]
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: notificationData
                        )
                        print("📢 EventDetail: Posted check-in notification for eventId: \(eventId)")
                    } else {
                        print("❌ EventDetail: Check in failed - \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id else {
            print("⚠️ EventDetail: Cannot check user check-in status: Missing user or user ID")
            return
        }
        
        // Use same event ID resolution as toggleCheckIn
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else {
            print("⚠️ EventDetail: Cannot check user check-in status: Missing event ID")
            return
        }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { isCheckedIn in
            DispatchQueue.main.async {
                self.isCheckedIn = isCheckedIn
                print("📊 EventDetail: User check-in status loaded: \(self.isCheckedIn)")
            }
        }
    }
    
    private func loadCheckInCount() {
        // Use same event ID resolution as toggleCheckIn
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else {
            print("⚠️ EventDetail: Cannot load check-in count: Missing event ID")
            return
        }
        
        // ENHANCED: Get both current and historical check-in counts
        checkInsService.getCombinedCheckInCount(for: eventId, itemType: "event") { currentCount, historicalCount in
            DispatchQueue.main.async {
                self.checkInCount = historicalCount  // Show TOTAL historical count instead of just current
                print("📊 EventDetail: Check-in count loaded - Current: \(currentCount), Historical: \(historicalCount), SHOWING: \(historicalCount)")
            }
        }
    }
    
    private func loadAttendees() {
        // Use same event ID resolution as toggleCheckIn
        let eventId: String
        if let id = event.id, !id.isEmpty {
            eventId = id
        } else {
            eventId = event.uniqueID
        }
        
        guard !eventId.isEmpty else {
            print("⚠️ EventDetail: Cannot load attendees: Missing event ID")
            return
        }
        
        isLoadingAttendees = true
        checkInsService.getMembersAtEvent(eventId) { members in
            DispatchQueue.main.async {
                self.attendees = members
                self.isLoadingAttendees = false
                print("👥 EventDetail: Loaded \(members.count) attendees")
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

// MARK: - Enhanced Attendee Card View (Bigger & Tappable)
struct AttendeeCardView: View {
    let member: FirebaseMember
    let currentUserCheckedIn: Bool
    @State private var selectedMember: FirebaseMember?
    @State private var showingDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile Image Header with conditional blur
            ZStack {
            CachedAsyncImage(url: member.profileImageURL) { image in
                let _ = print("✅ CHECKINS ASYNC: '\(member.firstName)' - Image loaded successfully in CheckInsView")
                image
                    .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .frame(height: 180)
                        .clipped()
                        .blur(radius: currentUserCheckedIn ? 0 : 8)
                        .background(Color.gray.opacity(0.1))
            } placeholder: {
                let _ = print("🖼️ CHECKINS ASYNC: '\(member.firstName)' - Loading placeholder in CheckInsView, URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                    ZStack {
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                        )
                        .frame(maxWidth: .infinity, maxHeight: 180)
                        .frame(height: 180)
                        .clipped()
                        .blur(radius: currentUserCheckedIn ? 0 : 8)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.6))
                                .blur(radius: currentUserCheckedIn ? 0 : 6)
                        Text(member.firstName.prefix(1).uppercased())
                                .font(.title)
                            .fontWeight(.bold)
                                .foregroundColor(.gray.opacity(0.8))
                                .blur(radius: currentUserCheckedIn ? 0 : 6)
                        }
                    }
                }
                
                // Lock icon overlay if not checked in
                if !currentUserCheckedIn {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.title2)
                            .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                        .frame(width: 32, height: 32)
                                )
                                .padding(12)
                        }
                        Spacer()
                    }
                }
                
                // Check-in status border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(currentUserCheckedIn ? Color.green : Color.gray, lineWidth: 3)
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .frame(height: 180)
            }
            .cornerRadius(16, corners: [.topLeft, .topRight])
            
            // Member Info with conditional blur
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(currentUserCheckedIn ? member.firstName : "???")
                        .font(.headline)
                    .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer(minLength: 4)
                
                if let age = member.age {
                        Text(currentUserCheckedIn ? "\(age)" : "??")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .fixedSize()
                    }
                }
                
                if let city = member.city {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Text(currentUserCheckedIn ? city : "???")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                if let tip = member.approachTip, !tip.isEmpty {
                    Text(currentUserCheckedIn ? tip : "???")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .truncationMode(.tail)
                }
                
                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: currentUserCheckedIn ? "eye" : "eye.slash")
                        .font(.caption2)
                        .foregroundColor(currentUserCheckedIn ? .green : .orange)
                    Text(currentUserCheckedIn ? "Visible" : "Check in to view")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 160) // Similar to MemberCardView but slightly smaller for horizontal scroll
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onTapGesture {
            if currentUserCheckedIn {
                selectedMember = member
                showingDetail = true
                Haptics.lightImpact()
            } else {
                Haptics.errorNotification()
            }
        }
        .sheet(item: $selectedMember) { member in
            NavigationView {
                MemberDetailView(member: member)
            }
        }
        .scaleEffect(currentUserCheckedIn ? 1.0 : 0.95)
        .opacity(currentUserCheckedIn ? 1.0 : 0.8)
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

// MARK: - Supporting Views

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