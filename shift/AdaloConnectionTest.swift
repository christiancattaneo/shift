import Foundation
import Combine

// MARK: - Connection Test Utility
class AdaloConnectionTest: ObservableObject {
    @Published var isLoading = false
    @Published var connectionStatus = ""
    @Published var testResults: [String] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Test Configuration
    func testConfiguration() {
        connectionStatus = "Testing configuration..."
        testResults.removeAll()
        
        let validation = AdaloConfiguration.validateConfiguration()
        
        if validation.isValid {
            testResults.append("✅ Configuration is valid")
            testResults.append("✅ API Key: \(String(AdaloConfiguration.apiKey.prefix(8)))...")
            testResults.append("✅ App ID: \(AdaloConfiguration.appID)")
            testResults.append("✅ Base URL: \(AdaloConfiguration.baseURL)")
            connectionStatus = "Configuration valid - Ready to test connection"
        } else {
            testResults.append("❌ Configuration Error: \(validation.message)")
            connectionStatus = "Configuration invalid - Please update AdaloConfig.swift"
        }
    }
    
    // MARK: - Test API Connection
    func testConnection() {
        guard AdaloConfiguration.isConfigured else {
            connectionStatus = "❌ Please configure API credentials first"
            return
        }
        
        isLoading = true
        connectionStatus = "Testing connection to Users collection (expecting 651 records)..."
        testResults.append("🔄 Testing connection to existing Users collection...")
        
        // Test direct API call to the Users collection
        testUsersCollectionDirect()
    }
    
    private func testUsersCollectionDirect() {
        // Try different possible URL patterns for the Users collection
        let possibleURLs = [
            "\(AdaloConfiguration.baseURL)/collections/Users/records",
            "\(AdaloConfiguration.baseURL)/apps/\(AdaloConfiguration.appID)/collections/Users/records",
            "\(AdaloConfiguration.baseURL)/collections/users/records",
            "\(AdaloConfiguration.baseURL)/apps/\(AdaloConfiguration.appID)/collections/users/records"
        ]
        
        testURLs(possibleURLs, index: 0)
    }
    
    private func testURLs(_ urls: [String], index: Int) {
        guard index < urls.count else {
            isLoading = false
            connectionStatus = "❌ Could not connect to Users collection with any URL pattern"
            testResults.append("❌ All URL patterns failed. Check App ID and API structure.")
            testResults.append("💡 Expected: 651 user records in the collection")
            return
        }
        
        let urlString = urls[index]
        testResults.append("🔄 Trying: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            testResults.append("❌ Invalid URL: \(urlString)")
            testURLs(urls, index: index + 1)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(AdaloConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.testResults.append("❌ Network error: \(error.localizedDescription)")
                    self.testURLs(urls, index: index + 1)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.testResults.append("❌ No HTTP response")
                    self.testURLs(urls, index: index + 1)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    // Success! Parse the response
                    self.handleSuccessfulConnection(data: data, url: urlString)
                } else if httpResponse.statusCode == 404 {
                    self.testResults.append("❌ 404 - Collection not found at this URL")
                    self.testURLs(urls, index: index + 1)
                } else {
                    let errorData = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No error details"
                    self.testResults.append("❌ HTTP \(httpResponse.statusCode): \(errorData)")
                    
                    if httpResponse.statusCode == 401 {
                        // Don't try other URLs if auth fails
                        self.isLoading = false
                        self.connectionStatus = "❌ Authentication failed - check API key"
                        self.testResults.append("🔑 API Key: \(AdaloConfiguration.apiKey.prefix(10))...")
                        return
                    }
                    
                    self.testURLs(urls, index: index + 1)
                }
            }
        }.resume()
    }
    
    private func handleSuccessfulConnection(data: Data?, url: String) {
        isLoading = false
        connectionStatus = "✅ Successfully connected to Users collection!"
        testResults.append("✅ SUCCESS! Connected via: \(url)")
        
        guard let data = data else {
            testResults.append("⚠️ No data returned")
            return
        }
        
        // Try to parse the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let recordsArray = json["records"] as? [[String: Any]] ?? []
                testResults.append("📊 Found \(recordsArray.count) user records")
                
                if recordsArray.count == 651 {
                    testResults.append("🎉 Perfect! Got expected 651 records")
                } else if recordsArray.count > 0 {
                    testResults.append("ℹ️ Expected 651 records, got \(recordsArray.count)")
                }
                
                // Show sample user data
                if let firstUser = recordsArray.first {
                    let email = firstUser["Email"] as? String ?? "No email"
                    let firstName = firstUser["First Name"] as? String ?? "No name"
                    testResults.append("👤 Sample user: \(firstName) (\(email))")
                    
                    // Check key fields
                    let hasID = firstUser["ID"] != nil
                    let hasEmail = firstUser["Email"] != nil
                    let hasPhoto = firstUser["Photo"] != nil
                    testResults.append("🔍 Fields: ID=\(hasID), Email=\(hasEmail), Photo=\(hasPhoto)")
                }
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "Binary data"
                testResults.append("⚠️ Unexpected response format:")
                testResults.append(String(responseString.prefix(200)))
            }
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Binary data"
            testResults.append("⚠️ JSON parsing error: \(error)")
            testResults.append("Raw response: \(String(responseString.prefix(200)))")
        }
    }
    
    // MARK: - Test Collections
    func testCollections() {
        guard AdaloConfiguration.isConfigured else {
            connectionStatus = "❌ Please configure API credentials first"
            return
        }
        
        isLoading = true
        connectionStatus = "Testing collections..."
        testResults.append("🔄 Testing all collections...")
        
        let collections = ["users", "members", "events", "conversations", "messages", "check_ins"]
        var completedTests = 0
        
        for collection in collections {
            testCollection(collection) { [weak self] result in
                completedTests += 1
                self?.testResults.append(result)
                
                if completedTests == collections.count {
                    self?.isLoading = false
                    self?.connectionStatus = "Collection tests completed"
                }
            }
        }
    }
    
    private func testCollection(_ collectionName: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: "\(AdaloConfiguration.baseURL)/apps/\(AdaloConfiguration.appID)/collections/\(collectionName)") else {
            completion("❌ \(collectionName): Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(AdaloConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion("❌ \(collectionName): \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion("❌ \(collectionName): Invalid response")
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    completion("✅ \(collectionName): Collection accessible")
                case 401:
                    completion("❌ \(collectionName): Unauthorized (check API key)")
                case 404:
                    completion("❌ \(collectionName): Collection not found")
                default:
                    completion("❌ \(collectionName): HTTP \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func handleConnectionError(_ error: NetworkError) {
        switch error {
        case .unauthorized:
            testResults.append("❌ Unauthorized - Check your API key")
            connectionStatus = "❌ API key is invalid"
        case .invalidURL:
            testResults.append("❌ Invalid URL - Check your App ID")
            connectionStatus = "❌ App ID is invalid"
        case .serverError(let code):
            testResults.append("❌ Server error: HTTP \(code)")
            connectionStatus = "❌ Server error"
        case .rateLimited:
            testResults.append("❌ Rate limited - too many requests")
            connectionStatus = "❌ Rate limited"
        case .noData:
            testResults.append("❌ No data received")
            connectionStatus = "❌ No response from server"
        case .decodingError(let error):
            testResults.append("❌ Data parsing error: \(error.localizedDescription)")
            connectionStatus = "❌ Invalid response format"
        }
    }
    
    // MARK: - Get Credentials Instructions
    func getCredentialsInstructions() -> [String] {
        return [
            "To get your Adalo credentials:",
            "",
            "1. Go to https://app.adalo.com",
            "2. Sign in to your account",
            "3. Open your Shift app",
            "4. Look at the URL - copy the App ID",
            "   Example: https://app.adalo.com/apps/12345",
            "   Your App ID is: 12345",
            "",
            "5. Click the settings gear (⚙️) in left menu",
            "6. Expand 'App Access' section",
            "7. Click 'Generate API Key'",
            "8. Copy the generated API key",
            "",
            "9. Update AdaloConfig.swift with your credentials",
            "10. You need Team plan ($200/month) for API access"
        ]
    }
} 