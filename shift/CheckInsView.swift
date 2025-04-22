import SwiftUI
import MapKit // Import MapKit

// Placeholder data structure for events/places
struct EventPlace: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    // Add coordinate later if needed for map annotations
}

struct CheckInsView: View {
    // Use MapCameraPosition for iOS 17+
    @State private var region = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.758896, longitude: -73.985130),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    
    @State private var searchText = ""

    // Placeholder data
    let places: [EventPlace] = [
        EventPlace(name: "Space Cowboy", address: "1917 East 7th Street"),
        EventPlace(name: "Museum of Modern Art", address: "11 W 53rd St"),
        EventPlace(name: "Central Park", address: "New York, NY")
    ]

    var body: some View {
        // Wrap content in NavigationView to enable NavigationLinks
        NavigationView {
            VStack(spacing: 0) {
                // Custom Header
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Check Ins")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        Image("shiftlogo") // Assuming logo is in assets
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                    }
                    Text("Meet singles near you")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                // Map View - Use newer initializer
                Map(position: $region)
                    .frame(height: 250) 

                // Events & Places Section
                VStack(spacing: 15) {
                    // Section Header
                    HStack {
                        Text("Events & Places")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button {
                            // TODO: Add action for adding event/place
                            print("Add Event/Place Tapped")
                        } label: {
                            Text("+ ADD")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }

                    // Search Bar Placeholder
                    TextField("Search...", text: $searchText)
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
                                    Button(action: { self.searchText = "" }) {
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                            }
                        )

                    // List of Places/Events
                    List {
                        ForEach(places) { place in
                            // Wrap row in NavigationLink
                            NavigationLink(destination: EventDetailView(place: place)) {
                                EventPlaceRow(place: place)
                            }
                            .listRowInsets(EdgeInsets()) // Apply to link if needed
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 5)
                        }
                    }
                    .listStyle(.plain) // Use plain style to remove default List background/styling
                    .padding(.top, -8) // Reduce space above list from search bar
                }
                .padding()
                
                Spacer() 
            }
            .navigationBarHidden(true) // Hide default nav bar
        }
        .accentColor(.blue) // Set accent for potential navigation elements
    }
}

// Row View for each event/place
struct EventPlaceRow: View {
    let place: EventPlace

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(place.name)
                    .font(.headline)
                Text(place.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "mappin.circle.fill") // Example icon
                .foregroundColor(.gray)
                .padding(.trailing, 5)
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    CheckInsView()
} 