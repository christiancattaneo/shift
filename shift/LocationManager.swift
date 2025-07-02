import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isUpdatingLocation = false
    
    static let shared = LocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
    }
    
    // MARK: - Public Methods
    
    func requestLocationPermission() {
        print("📍 Requesting location permission...")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location not authorized")
            locationError = "Location access is required to check in to events. Please enable location permissions in Settings."
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            print("❌ Location services disabled")
            locationError = "Location services are disabled. Please enable them in Settings."
            return
        }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
        print("📍 Started location updates")
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        print("📍 Stopped location updates")
    }
    
    func requestOneTimeLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        isUpdatingLocation = true
        locationManager.requestLocation()
        print("📍 Requesting one-time location")
    }
    
    // MARK: - Location Validation
    
    func isWithinCheckInRange(of eventCoordinates: EventCoordinates, maxDistance: Double = 1609.34) -> Bool {
        // maxDistance defaults to 1 mile in meters (1609.34 meters = 1 mile)
        guard let userLocation = location else {
            print("❌ User location not available")
            return false
        }
        
        let eventLocation = CLLocation(
            latitude: eventCoordinates.latitude,
            longitude: eventCoordinates.longitude
        )
        
        let distance = userLocation.distance(from: eventLocation)
        print("📍 Distance to event: \(String(format: "%.0f", distance))m (\(String(format: "%.2f", distance * 0.000621371)) miles)")
        
        return distance <= maxDistance
    }
    
    func distanceToEvent(_ eventCoordinates: EventCoordinates) -> CLLocationDistance? {
        guard let userLocation = location else { return nil }
        
        let eventLocation = CLLocation(
            latitude: eventCoordinates.latitude,
            longitude: eventCoordinates.longitude
        )
        
        return userLocation.distance(from: eventLocation)
    }
    
    // MARK: - City Matching
    
    func isInSameCity(as targetCity: String) -> Bool {
        guard let userLocation = location else { return false }
        
        // Use reverse geocoding to get user's city
        let geocoder = CLGeocoder()
        var result = false
        let semaphore = DispatchSemaphore(value: 0)
        
        geocoder.reverseGeocodeLocation(userLocation) { placemarks, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("❌ Reverse geocoding error: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first,
                  let userCity = placemark.locality else {
                print("❌ Could not determine user's city")
                return
            }
            
            result = userCity.lowercased() == targetCity.lowercased()
            print("📍 User city: \(userCity), Target city: \(targetCity), Match: \(result)")
        }
        
        // Wait for geocoding to complete (with timeout)
        _ = semaphore.wait(timeout: .now() + 3.0)
        return result
    }
    
    // Async version for better performance
    func isInSameCity(as targetCity: String) async -> Bool {
        guard let userLocation = location else { return false }
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(userLocation)
            guard let placemark = placemarks.first,
                  let userCity = placemark.locality else {
                print("❌ Could not determine user's city")
                return false
            }
            
            let result = userCity.lowercased() == targetCity.lowercased()
            print("📍 User city: \(userCity), Target city: \(targetCity), Match: \(result)")
            return result
        } catch {
            print("❌ Reverse geocoding error: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        location = newLocation
        isUpdatingLocation = false
        locationError = nil
        
        print("📍 Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude)")
        print("📍 Accuracy: \(newLocation.horizontalAccuracy)m")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isUpdatingLocation = false
        locationError = error.localizedDescription
        print("❌ Location error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        print("📍 Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("📍 Location permission not determined")
        case .restricted, .denied:
            locationError = "Location access denied. Please enable location permissions in Settings to check in to events."
            print("❌ Location permission denied")
        case .authorizedWhenInUse, .authorizedAlways:
            locationError = nil
            print("✅ Location permission granted")
        @unknown default:
            print("📍 Unknown location authorization status")
        }
    }
}

// MARK: - Location Permission Alert Helper
struct LocationPermissionAlert: View {
    let isPresented: Binding<Bool>
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Location Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("To check in to events, we need to verify you're within 1 mile of the location. Your location is only used for check-ins and never shared with other users.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Button("Enable Location") {
                    onRequestPermission()
                    isPresented.wrappedValue = false
                }
                .buttonStyle(.borderedProminent)
                
                Button("Open Settings") {
                    onOpenSettings()
                    isPresented.wrappedValue = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(30)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
    }
}

// MARK: - Distance Display Helper
extension LocationManager {
    func formattedDistance(to eventCoordinates: EventCoordinates) -> String {
        guard let distance = distanceToEvent(eventCoordinates) else {
            return "Distance unknown"
        }
        
        let miles = distance * 0.000621371
        
        if miles < 0.1 {
            return "Less than 0.1 miles"
        } else if miles < 1 {
            return String(format: "%.1f miles", miles)
        } else {
            return String(format: "%.1f miles", miles)
        }
    }
    
    var hasLocationPermission: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var needsLocationPermission: Bool {
        return authorizationStatus == .notDetermined
    }
    
    var locationDenied: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }
} 