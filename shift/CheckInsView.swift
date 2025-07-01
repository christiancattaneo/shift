import SwiftUI
import MapKit
import Combine
import CoreLocation

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
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadImage()
                    }
            }
        }
    }
    
    private func loadImage() {
        guard let url = url, cachedImage == nil && !isLoading else { 
            if url == nil {
                print("❌ CACHED: No URL provided for image")
            }
            return 
        }
        
        print("🖼️ CACHED: Starting to load image from: \(url.absoluteString)")
        
        // Check cache first
        if let cachedImage = ImageCache.shared.getImage(for: url.absoluteString) {
            print("✅ CACHED: Found image in cache for: \(url.absoluteString)")
            self.cachedImage = cachedImage
            return
        }
        
        print("🔄 CACHED: Image not in cache, downloading from: \(url.absoluteString)")
        isLoading = true
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 CACHED: HTTP Response \(httpResponse.statusCode) for: \(url.absoluteString)")
                    if httpResponse.statusCode != 200 {
                        print("❌ CACHED: HTTP error \(httpResponse.statusCode) for: \(url.absoluteString)")
                    }
                }
                
                if let uiImage = UIImage(data: data) {
                    print("✅ CACHED: Successfully loaded image (\(data.count) bytes) from: \(url.absoluteString)")
                    await MainActor.run {
                        ImageCache.shared.setImage(uiImage, for: url.absoluteString)
                        self.cachedImage = uiImage
                        self.isLoading = false
                    }
                } else {
                    print("❌ CACHED: Failed to create UIImage from data (\(data.count) bytes) for: \(url.absoluteString)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } catch {
                print("❌ CACHED: Network error loading \(url.absoluteString): \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
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

struct CheckInsView: View {
    @State private var region = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431), // Austin, Texas
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    )
    @State private var locationManager = CLLocationManager()
    
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @StateObject private var eventsService = FirebaseEventsService()
    @StateObject private var checkInsService = FirebaseCheckInsService()
    
    private let filters = ["All", "Tonight", "This Week", "Nearby"]
    
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
        case "Nearby":
            // For now, return all events. Could implement actual location filtering
            print("📍 EVENTS: 'Nearby' filter: keeping all \(events.count) events")
        default:
            print("🌐 EVENTS: 'All' filter: keeping all \(events.count) events")
        }
        
        print("🎯 EVENTS: Final result: \(events.count) events will be displayed")
        return events
    }


    var body: some View {
        VStack(spacing: 0) {
            // Custom Header Section
            customHeaderSection
            
            // Map Section
            mapSection
            
            // Content Section
            if eventsService.isLoading {
                loadingSection
                    .onAppear {
                        print("🔄 EVENTS UI: Showing loading section")
                    }
            } else if filteredEvents.isEmpty {
                emptyStateSection
                    .onAppear {
                        print("❌ EVENTS UI: Showing empty state - isLoading: \(eventsService.isLoading), serviceEvents: \(eventsService.events.count), filteredEvents: \(filteredEvents.count)")
                    }
            } else {
                eventsListSection
                    .onAppear {
                        print("✅ EVENTS UI: Showing events list with \(filteredEvents.count) events")
                    }
            }
        }
        .refreshable {
            await refreshEvents()
        }
        .onAppear {
            setupInitialState()
        }
    }
    
    // MARK: - UI Components
    
    private var customHeaderSection: some View {
        VStack(spacing: 16) {
            // Title Section
            HStack {
                Text("Discover Events")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Search and Filter Section
            searchAndFilterSection
        }
        .background(Color(.systemBackground))
    }
    
    private var searchAndFilterSection: some View {
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
        .padding(.bottom, 12)
    }
    
    private var mapSection: some View {
        VStack(spacing: 8) {
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
                .frame(height: 180)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .onAppear {
                    requestLocationPermission()
                }
        }
        .padding(.vertical, 8)
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
            LazyVStack(spacing: 12) {
                ForEach(filteredEvents, id: \.uniqueID) { event in
                    NavigationLink(destination: EventDetailView(event: event)) {
                        EventCardView(event: event)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupInitialState() {
        print("🚀 EVENTS: Setting up initial state")
        print("🚀 EVENTS: eventsService.isLoading = \(eventsService.isLoading)")
        print("🚀 EVENTS: eventsService.events.count = \(eventsService.events.count)")
        eventsService.fetchEvents()
        checkInsService.fetchCheckIns()
        print("🚀 EVENTS: Fetch initiated - eventsService.isLoading = \(eventsService.isLoading)")
    }
    
    private func refreshEvents() async {
        eventsService.fetchEvents()
        checkInsService.fetchCheckIns()
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    private func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
        
        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            if let userLocation = locationManager.location {
                withAnimation(.easeInOut(duration: 1.0)) {
                    region = MapCameraPosition.region(
                        MKCoordinateRegion(
                            center: userLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EventCardView: View {
    let event: FirebaseEvent
    @State private var isCheckedIn = false
    @State private var checkInCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Event Image Header
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
            }
            
            // Event Details
            VStack(spacing: 12) {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isCheckedIn ? Color.clear : Color.blue.opacity(0.3), lineWidth: 1)
                    )
                }
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
    }
    
    private func toggleCheckIn() {
        Haptics.lightImpact()
        isCheckedIn.toggle()
        if isCheckedIn {
            checkInCount += 1
            Haptics.successNotification()
        } else {
            checkInCount = max(0, checkInCount - 1)
        }
    }
    
    private func checkIfUserCheckedIn() {
        isCheckedIn = false
    }
    
    private func loadCheckInCount() {
        checkInCount = Int.random(in: 2...15)
    }
    
    private func formatEventDate(_ date: Date) -> String {
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
    
    private var eventImagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.9))
                Text(event.name.prefix(1).uppercased())
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.9))
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
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
                    Text(event.name)
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