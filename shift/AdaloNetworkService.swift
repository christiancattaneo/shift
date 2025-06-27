import Foundation
import Combine

// Configuration is now in AdaloConfig.swift

// MARK: - API Response Models
// Adalo API returns records directly in an array, not wrapped in a "records" object
struct AdaloListResponse<T: Codable>: Codable {
    let records: [T]
}

struct AdaloSingleResponse<T: Codable>: Codable {
    let data: T?
}

// MARK: - Error Types
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int)
    case unauthorized
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .unauthorized:
            return "Unauthorized access - check API key"
        case .rateLimited:
            return "Rate limit exceeded"
        }
    }
}

// MARK: - Network Service
class AdaloNetworkService: ObservableObject {
    static let shared = AdaloNetworkService()
    
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Base Request Method
    private func createRequest(for endpoint: String, method: HTTPMethod = .GET, body: Data? = nil) -> URLRequest? {
        // Construct the correct Adalo API URL format
        let urlString = "\(AdaloConfiguration.baseURL)/apps/\(AdaloConfiguration.appID)/collections/\(endpoint)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("Bearer \(AdaloConfiguration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let body = body {
            request.httpBody = body
        }
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🌐 API Request: \(method.rawValue) \(url)")
            print("🔑 Auth: Bearer \(AdaloConfiguration.apiKey.prefix(10))...")
        }
        
        return request
    }
    
    // MARK: - Collection Operations
    func fetchCollection<T: Codable>(
        collectionName: String,
        responseType: T.Type
    ) -> AnyPublisher<[T], NetworkError> {
        // For collections, we need to add "/records" to the endpoint
        guard let request = createRequest(for: "\(collectionName)/records", method: .GET) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                
                if AdaloConfiguration.isLoggingEnabled {
                    print("📊 API Response: HTTP \(httpResponse.statusCode)")
                    print("📄 Response data: \(String(data: data, encoding: .utf8)?.prefix(200) ?? "No data")")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .tryMap { data -> [T] in
                // Try to decode as direct array first (most common format)
                do {
                    let records = try JSONDecoder().decode([T].self, from: data)
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully decoded \(records.count) records as direct array")
                    }
                    return records
                } catch {
                    if AdaloConfiguration.isLoggingEnabled {
                        print("⚠️ Direct array decode failed, trying wrapped format...")
                    }
                    
                    // Try wrapped format {"records": [...]}
                    do {
                        let response = try JSONDecoder().decode(AdaloListResponse<T>.self, from: data)
                        if AdaloConfiguration.isLoggingEnabled {
                            print("✅ Successfully decoded \(response.records.count) records as wrapped format")
                        }
                        return response.records
                    } catch {
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Both decode attempts failed. Raw data: \(String(data: data, encoding: .utf8) ?? "No data")")
                        }
                        throw NetworkError.decodingError(error)
                    }
                }
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return .decodingError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func createRecord<T: Codable>(
        in collectionName: String,
        data: T
    ) -> AnyPublisher<T, NetworkError> {
        guard let jsonData = try? JSONEncoder().encode(data) else {
            return Fail(error: NetworkError.decodingError(NSError(domain: "Encoding", code: 0)))
                .eraseToAnyPublisher()
        }
        
        guard let request = createRequest(for: "\(collectionName)/records", method: .POST, body: jsonData) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> NetworkError in
                if error is DecodingError {
                    return .decodingError(error)
                }
                return .serverError(0)
            }
            .eraseToAnyPublisher()
    }
    
    func updateRecord<T: Codable>(
        in collectionName: String,
        recordID: String,
        data: T
    ) -> AnyPublisher<T, NetworkError> {
        guard let jsonData = try? JSONEncoder().encode(data) else {
            return Fail(error: NetworkError.decodingError(NSError(domain: "Encoding", code: 0)))
                .eraseToAnyPublisher()
        }
        
        guard let request = createRequest(for: "\(collectionName)/records/\(recordID)", method: .PUT, body: jsonData) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error -> NetworkError in
                if error is DecodingError {
                    return .decodingError(error)
                }
                return .serverError(0)
            }
            .eraseToAnyPublisher()
    }
    
    func deleteRecord(
        from collectionName: String,
        recordID: String
    ) -> AnyPublisher<Bool, NetworkError> {
        guard let request = createRequest(for: "\(collectionName)/records/\(recordID)", method: .DELETE) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return true
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return .serverError(0)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Generic Request Method for Raw Data
    func performRawRequest(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Data? = nil
    ) -> AnyPublisher<Data, NetworkError> {
        guard let request = createRequest(for: endpoint, method: method, body: body) else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.noData
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw NetworkError.unauthorized
                case 429:
                    throw NetworkError.rateLimited
                default:
                    throw NetworkError.serverError(httpResponse.statusCode)
                }
            }
            .mapError { error -> NetworkError in
                if let networkError = error as? NetworkError {
                    return networkError
                }
                return .serverError(0)
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - HTTP Methods
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Helper Types
struct EmptyResponse: Codable {} 