import SwiftUI
import Combine

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
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedEvent: FirebaseEvent? = nil
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
        
        // Filter out events without images
        let beforeImageFilter = events.count
        events = events.filter { event in
            let hasImage = event.imageURL != nil
            if !hasImage {
                print("🖼️ EVENTS: Filtering out event '\(event.eventName ?? event.venueName ?? "Unknown")' - no image available")
            }
            return hasImage
        }
        print("📸 EVENTS: After image filter: \(events.count) events (filtered out \(beforeImageFilter - events.count) without images)")
        
        print("🎯 EVENTS: Final result: \(events.count) events will be displayed")
        return events
    }


    var body: some View {
        VStack(spacing: 0) {
            // Custom Header Section
            customHeaderSection
            
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
        .sheet(item: $selectedEvent) { event in
            NavigationView {
                EventDetailView(event: event)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                selectedEvent = nil
                            }
                        }
                    }
            }
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
                    EventCardView(
                        event: event,
                        checkInsService: checkInsService,
                        onCardTap: {
                            // Handle card tap to navigate to event detail
                            print("🎯 Card tapped for event: \(event.name)")
                            selectedEvent = event
                        }
                    )
                    .id(event.uniqueID)
                    .animation(.none, value: event.uniqueID)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .clipped()
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
    

}

// MARK: - Supporting Views

struct EventCardView: View {
    let event: FirebaseEvent
    let checkInsService: FirebaseCheckInsService
    let onCardTap: () -> Void
    
    @State private var isCheckedIn = false
    @State private var checkInCount = 0
    @State private var isProcessing = false
    
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
                
                // Check-in Button - Isolated with exclusive gesture
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
                            Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "plus.circle")
                                .font(.subheadline)
                        }
                        Text(isProcessing ? "Processing..." : (isCheckedIn ? "Check Out" : "Check In"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isCheckedIn ? .white : .blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
            if let eventId = notification.userInfo?["eventId"] as? String, eventId == event.id {
                print("🔄 Refreshing check-in status for event: \(event.name)")
                checkIfUserCheckedIn()
                loadCheckInCount()
            }
        }
    }
    
    private func toggleCheckIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else {
            print("❌ Cannot check in: Missing user or event ID")
            return
        }
        
        guard !isProcessing else { 
            print("⚠️ Check-in already in progress")
            return 
        }
        
        print("🎯 Starting check-in process for user \(userId) at event \(eventId)")
        Haptics.lightImpact()
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            print("🔄 Checking out...")
            checkInsService.checkOut(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        self.isCheckedIn = false
                        self.checkInCount = max(0, self.checkInCount - 1)
                        Haptics.successNotification()
                        print("✅ Successfully checked out of event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": false]
                        )
                    } else {
                        print("❌ Check out failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in
            print("🔄 Checking in...")
            checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        self.isCheckedIn = true
                        self.checkInCount += 1
                        Haptics.successNotification()
                        print("✅ Successfully checked in to event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": true]
                        )
                    } else {
                        print("❌ Check in failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else {
            print("⚠️ Cannot check user check-in status: Missing user or event ID")
            return
        }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { isCheckedIn in
            DispatchQueue.main.async {
                self.isCheckedIn = isCheckedIn
                print("📊 User check-in status loaded: \(isCheckedIn ? "checked in" : "not checked in")")
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let eventId = event.id else { 
            print("⚠️ Cannot load check-in count: Missing event ID")
            return 
        }
        
        checkInsService.getCheckInCount(for: eventId) { count in
            DispatchQueue.main.async {
                self.checkInCount = count
                print("📊 Check-in count loaded: \(count)")
            }
        }
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
                    
                    // Attendees Section
                    if !attendees.isEmpty || isLoadingAttendees {
                        attendeesSection
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
                Text("Who's Attending")
                    .font(.title2)
                    .fontWeight(.bold)
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
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(attendees, id: \.uniqueID) { member in
                        AttendeeCardView(member: member)
                    }
                }
                .padding(.horizontal, 20)
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
            print("❌ Cannot check in: Missing user or event ID")
            return
        }
        
        guard !isProcessing else { return }
        
        print("🎯 Starting check-in process for user \(userId) at event \(eventId)")
        Haptics.lightImpact()
        isProcessing = true
        
        if isCheckedIn {
            // Check out
            checkInsService.checkOut(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        self.isCheckedIn = false
                        self.checkInCount = max(0, self.checkInCount - 1)
                        self.loadAttendees() // Refresh attendees list
                        Haptics.successNotification()
                        print("✅ Successfully checked out of event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": false]
                        )
                    } else {
                        print("❌ Check out failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        } else {
            // Check in
            checkInsService.checkIn(userId: userId, eventId: eventId) { success, error in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        self.isCheckedIn = true
                        self.checkInCount += 1
                        self.loadAttendees() // Refresh attendees list
                        Haptics.successNotification()
                        print("✅ Successfully checked in to event")
                        
                        // Notify other views about check-in status change
                        NotificationCenter.default.post(
                            name: .checkInStatusChanged,
                            object: nil,
                            userInfo: ["eventId": eventId, "isCheckedIn": true]
                        )
                    } else {
                        print("❌ Check in failed: \(error ?? "Unknown error")")
                        Haptics.errorNotification()
                    }
                }
            }
        }
    }
    
    private func checkIfUserCheckedIn() {
        guard let currentUser = FirebaseUserSession.shared.currentUser,
              let userId = currentUser.id,
              let eventId = event.id else {
            return
        }
        
        checkInsService.isUserCheckedIn(userId: userId, eventId: eventId) { isCheckedIn in
            DispatchQueue.main.async {
                self.isCheckedIn = isCheckedIn
                print("📊 User check-in status: \(isCheckedIn ? "checked in" : "not checked in")")
            }
        }
    }
    
    private func loadCheckInCount() {
        guard let eventId = event.id else { return }
        
        checkInsService.getCheckInCount(for: eventId) { count in
            DispatchQueue.main.async {
                self.checkInCount = count
                print("📊 Check-in count: \(count)")
            }
        }
    }
    
    private func loadAttendees() {
        guard let eventId = event.id else { return }
        
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
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                case .failure(_), .empty:
                    Circle()
                        .fill(LinearGradient(
                            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
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
                @unknown default:
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                }
            }
            
            // Name and Details
            VStack(spacing: 2) {
                Text(member.firstName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                if let age = member.age {
                    Text("\(age)")
                        .font(.caption2)
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
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    CheckInsView()
} 