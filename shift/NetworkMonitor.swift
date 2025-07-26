import Foundation
import Network
import SwiftUI

@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var hasLimitedConnectivity = false
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case unavailable
        
        var description: String {
            switch self {
            case .wifi:
                return "Wi-Fi"
            case .cellular:
                return "Cellular"
            case .ethernet:
                return "Ethernet"
            case .unknown:
                return "Unknown"
            case .unavailable:
                return "No Connection"
            }
        }
        
        var icon: String {
            switch self {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .ethernet:
                return "cable.connector"
            case .unknown:
                return "questionmark.circle"
            case .unavailable:
                return "wifi.slash"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
                self?.hasLimitedConnectivity = path.isConstrained
                self?.updateConnectionType(path)
                
                if path.status == .satisfied {
                    print("🌐 Network connected: \(self?.connectionType.description ?? "")")
                } else {
                    print("❌ Network disconnected")
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.status == .unsatisfied {
            connectionType = .unavailable
        } else if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
}

// MARK: - Network Alert View

struct NetworkAlertView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showAlert = false
    
    var body: some View {
        EmptyView()
            .onChange(of: networkMonitor.isConnected) { oldValue, newValue in
                if !newValue && oldValue {
                    showAlert = true
                }
            }
            .alert("No Internet Connection", isPresented: $showAlert) {
                Button("OK") { }
                if networkMonitor.isConnected {
                    Button("Retry") {
                        showAlert = false
                    }
                }
            } message: {
                Text("Please check your internet connection and try again.")
            }
    }
}

// MARK: - Offline Banner View

struct OfflineBannerView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 8) {
                Image(systemName: networkMonitor.connectionType.icon)
                    .font(.caption)
                
                Text("No Internet Connection")
                    .font(.caption)
                    .fontWeight(.medium)
                
                if networkMonitor.hasLimitedConnectivity {
                    Text("• Limited")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.red)
            .cornerRadius(20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: networkMonitor.isConnected)
        }
    }
} 