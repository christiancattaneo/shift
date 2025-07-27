import SwiftUI
import PhotosUI
import CoreLocation
import FirebaseFirestore
import FirebaseStorage

struct AddEventPlaceView: View {
    let selectedContentType: CheckInsView.ContentType
    let eventsService: FirebaseEventsService
    let placesService: FirebasePlacesService
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var locationManager = LocationManager.shared
    
    // Common fields
    @State private var name = ""
    @State private var location = ""
    @State private var selectedCoordinates: CLLocationCoordinate2D?
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Event-specific fields
    @State private var venueName = ""
    @State private var startTime = Date()
    @State private var endTime = Date()
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    
    // Location search
    @State private var isSearchingLocation = false
    @State private var locationSearchResults: [CLPlacemark] = []
    @State private var showLocationPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection
                        
                        // Form fields
                        if selectedContentType == .events {
                            eventFormFields
                        } else {
                            placeFormFields
                        }
                        
                        // Image picker
                        imagePickerSection
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
                
                // Bottom buttons
                VStack {
                    Spacer()
                    bottomButtonsSection
                }
            }
        }
        .onAppear {
            // Set default times for events
            if selectedContentType == .events {
                let now = Date()
                startTime = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
                endTime = Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now
            }
        }
        .onChange(of: selectedImageItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                searchText: $location,
                selectedCoordinates: $selectedCoordinates,
                onLocationSelected: { placemark in
                    location = placemark.name ?? placemark.locality ?? ""
                    selectedCoordinates = placemark.location?.coordinate
                    showLocationPicker = false
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            Text(selectedContentType == .events ? "Add Event" : "Add Place")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }
    
    private var eventFormFields: some View {
        VStack(spacing: 20) {
            // Event Name
            FormField(
                title: "Event Name",
                text: $name,
                placeholder: "Enter event name...",
                isRequired: false
            )
            
            // Venue Name (Required)
            FormField(
                title: "Venue Name (required)",
                text: $venueName,
                placeholder: "Enter venue name...",
                isRequired: true
            )
            
            // Event Location (Required)
            locationField
            
            // Event Start Time
            timeField(
                title: "Event Start Time (optional)",
                date: $startTime,
                showPicker: $showStartTimePicker
            )
            
            // Event End Time
            timeField(
                title: "Event End Time (optional)",
                date: $endTime,
                showPicker: $showEndTimePicker
            )
        }
    }
    
    private var placeFormFields: some View {
        VStack(spacing: 20) {
            // Place Name (Required)
            FormField(
                title: "Place Name (required)",
                text: $name,
                placeholder: "Enter place name...",
                isRequired: true
            )
            
            // Place Location (Required)
            locationField
        }
    }
    
    private var locationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedContentType == .events ? "Event Location (required)" : "Place Location (required)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Button(action: {
                showLocationPicker = true
            }) {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    
                    Text(location.isEmpty ? "Search by name or address..." : location)
                        .foregroundColor(location.isEmpty ? .secondary : .white)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
            }
        }
    }
    
    private func timeField(title: String, date: Binding<Date>, showPicker: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Button(action: {
                showPicker.wrappedValue.toggle()
            }) {
                Text(formatDateTime(date.wrappedValue))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange, lineWidth: 2)
                    )
            }
            
            if showPicker.wrappedValue {
                DatePicker(
                    "",
                    selection: date,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .colorScheme(.dark)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image (optional)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            PhotosPicker(
                selection: $selectedImageItem,
                matching: .images
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                    
                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("Choose Photo")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }
    
    private var bottomButtonsSection: some View {
        VStack(spacing: 16) {
            // Error message
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            // Create button
            Button(action: createItem) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text(selectedContentType == .events ? "CREATE EVENT" : "CREATE PLACE")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: isFormValid ? [.blue, .purple] : [.gray, .gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isLoading)
            .padding(.horizontal, 24)
            
            // Back button
            Button("BACK") {
                dismiss()
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange, lineWidth: 2)
            )
            .padding(.horizontal, 24)
            
            // Shift logo
            Image("shiftlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(.bottom, 20)
        }
        .background(Color.black)
    }
    
    private var isFormValid: Bool {
        if selectedContentType == .events {
            return !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private func createItem() {
        guard isFormValid else { return }
        
        isLoading = true
        errorMessage = nil
        
        if selectedContentType == .events {
            createEvent()
        } else {
            createPlace()
        }
    }
    
    private func createEvent() {
        guard let userId = FirebaseUserSession.shared.currentUser?.id else {
            errorMessage = "User not logged in"
            isLoading = false
            return
        }
        
        // Create event data
        let eventData: [String: Any] = [
            "eventName": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "venueName": venueName.trimmingCharacters(in: .whitespacesAndNewlines),
            "eventLocation": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "eventStartTime": formatDateTime(startTime),
            "eventEndTime": formatDateTime(endTime),
            "eventDate": DateFormatter().with { $0.dateFormat = "yyyy-MM-dd" }.string(from: startTime),
            "coordinates": selectedCoordinates.map { [
                "latitude": $0.latitude,
                "longitude": $0.longitude
            ] } as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "createdBy": userId,
            "isEventFree": true, // Default to free
            "eventCategory": "User Created"
        ]
        
        let db = Firestore.firestore()
        
        // Create event document
        var eventRef: DocumentReference? = nil
        eventRef = db.collection("events").addDocument(data: eventData) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create event: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let eventId = eventRef?.documentID else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to get event ID"
                    self.isLoading = false
                }
                return
            }
            
            // Upload image if selected
            if let imageData = self.selectedImageData {
                self.uploadImage(imageData, path: "event_images/\(eventId).jpg") { imageUrl in
                    // Update event with image URL
                    eventRef?.updateData(["imageUrl": imageUrl, "firebaseImageUrl": imageUrl]) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("Failed to update event with image: \(error)")
                            }
                            self.finishCreation()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.finishCreation()
                }
            }
        }
    }
    
    private func createPlace() {
        guard let userId = FirebaseUserSession.shared.currentUser?.id else {
            errorMessage = "User not logged in"
            isLoading = false
            return
        }
        
        // Create place data
        let placeData: [String: Any] = [
            "placeName": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "placeLocation": location.trimmingCharacters(in: .whitespacesAndNewlines),
            "coordinates": selectedCoordinates.map { [
                "latitude": $0.latitude,
                "longitude": $0.longitude
            ] } as Any,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "createdBy": userId,
            "isPlaceFree": true // Default to free
        ]
        
        let db = Firestore.firestore()
        
        // Create place document
        var placeRef: DocumentReference? = nil
        placeRef = db.collection("places").addDocument(data: placeData) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create place: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            guard let placeId = placeRef?.documentID else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to get place ID"
                    self.isLoading = false
                }
                return
            }
            
            // Upload image if selected
            if let imageData = self.selectedImageData {
                self.uploadImage(imageData, path: "place_images/\(placeId).jpg") { imageUrl in
                    // Update place with image URL
                    placeRef?.updateData(["imageUrl": imageUrl, "firebaseImageUrl": imageUrl]) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("Failed to update place with image: \(error)")
                            }
                            self.finishCreation()
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.finishCreation()
                }
            }
        }
    }
    
    private func uploadImage(_ imageData: Data, path: String, completion: @escaping (String) -> Void) {
        let storageRef = Storage.storage().reference().child(path)
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Failed to upload image: \(error)")
                return
            }
            
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Failed to get download URL: \(error)")
                    return
                }
                
                if let url = url {
                    completion(url.absoluteString)
                }
            }
        }
    }
    
    private func finishCreation() {
        isLoading = false
        
        // Refresh the appropriate service to show new item
        if selectedContentType == .events {
            eventsService.refreshEvents()
        } else {
            placesService.refreshPlaces()
        }
        
        Haptics.successNotification()
        dismiss()
    }
}

// MARK: - Supporting Views

struct FormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
        }
    }
}

struct LocationPickerView: View {
    @Binding var searchText: String
    @Binding var selectedCoordinates: CLLocationCoordinate2D?
    let onLocationSelected: (CLPlacemark) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var searchResults: [CLPlacemark] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search by name or address...", text: $searchText)
                        .onSubmit {
                            searchForLocation()
                        }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.self) { placemark in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(placemark.name ?? "Unknown location")
                                .font(.headline)
                            
                            if let address = formatAddress(placemark) {
                                Text(address)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onLocationSelected(placemark)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if !searchText.isEmpty {
                searchForLocation()
            }
        }
    }
    
    private func searchForLocation() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(searchText) { placemarks, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let error = error {
                    print("Geocoding error: \(error)")
                    searchResults = []
                    return
                }
                
                searchResults = placemarks ?? []
            }
        }
    }
    
    private func formatAddress(_ placemark: CLPlacemark) -> String? {
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode
        ].compactMap { $0 }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

extension DateFormatter {
    func with(_ configurator: (DateFormatter) -> Void) -> DateFormatter {
        configurator(self)
        return self
    }
}

#Preview {
    AddEventPlaceView(
        selectedContentType: .events,
        eventsService: FirebaseEventsService(),
        placesService: FirebasePlacesService()
    )
} 