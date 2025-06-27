import Foundation
import Combine

// MARK: - Authentication Service
// NOTE: Custom authentication using Adalo's Collections API is NOT SECURE
// Adalo's Collections API does not provide proper authentication endpoints.
// It only allows CRUD operations on data, not secure user authentication.
// 
// SECURITY ISSUE: Any attempt to "authenticate" by checking if email exists
// would allow anyone who knows an email to login as that user.
//
// SOLUTION: Use Adalo's built-in authentication system which is secure
// and handles proper password hashing, session management, etc.
//
// The login/signup views now use proper Adalo authentication instead of
// this insecure custom implementation.

// MARK: - Members Service (fetches from Users collection)
class AdaloMembersService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var members: [AdaloMember] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchMembers() {
        isLoading = true
        errorMessage = nil
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🔄 Fetching members from Users collection...")
        }
        
        // Fetch from the Users collection and convert to AdaloMember format
        networkService.fetchCollection(collectionName: "Users", responseType: AdaloUser.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Failed to fetch members: \(error.localizedDescription)")
                            print("🔄 Using mock data fallback...")
                        }
                        // Load mock data when API fails
                        self?.members = self?.getMockMembers() ?? []
                    }
                },
                receiveValue: { [weak self] users in
                    // Convert AdaloUser to AdaloMember for display
                    let members = users.compactMap { user -> AdaloMember? in
                        guard let firstName = user.firstName, !firstName.isEmpty else { return nil }
                        
                        return AdaloMember(
                            id: user.id,
                            firstName: firstName,
                            age: user.age,
                            city: user.city,
                            attractedTo: user.attractedTo,
                            approachTip: user.howToApproachMe,
                            instagramHandle: user.instagramHandle,
                            profileImage: user.profilePhoto
                        )
                    }
                    
                    self?.members = members
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully loaded \(members.count) members from \(users.count) users")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func createMember(_ member: AdaloMember) {
        networkService.createRecord(in: "Users", data: member)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newMember in
                    self?.members.append(newMember)
                }
            )
            .store(in: &cancellables)
    }
    
    func updateMember(_ member: AdaloMember) {
        networkService.updateRecord(in: "Users", recordID: "\(member.id)", data: member)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] updatedMember in
                    // Update local array
                    if let index = self?.members.firstIndex(where: { $0.id == updatedMember.id }) {
                        self?.members[index] = updatedMember
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockMembers() -> [AdaloMember] {
        return [
            AdaloMember(
                id: 1,
                firstName: "Sarah",
                age: 28,
                city: "San Francisco",
                attractedTo: "Men",
                approachTip: "Ask me about my travels!",
                instagramHandle: "@sarah_travels",
                profileImage: "https://picsum.photos/400/400?random=101"
            ),
            AdaloMember(
                id: 2,
                firstName: "Jake",
                age: 32,
                city: "San Francisco",
                attractedTo: "Women",
                approachTip: "Let's grab coffee and talk tech",
                instagramHandle: "@jake_codes",
                profileImage: "https://picsum.photos/400/400?random=102"
            ),
            AdaloMember(
                id: 3,
                firstName: "Emma",
                age: 26,
                city: "San Francisco",
                attractedTo: "Anyone",
                approachTip: "I love discussing books and art",
                instagramHandle: "@emma_reads",
                profileImage: "https://picsum.photos/400/400?random=103"
            ),
            AdaloMember(
                id: 4,
                firstName: "Carlos",
                age: 30,
                city: "San Francisco",
                attractedTo: "Women",
                approachTip: "Ask me about my cooking!",
                instagramHandle: "@carlos_chef",
                profileImage: "https://picsum.photos/400/400?random=104"
            ),
            AdaloMember(
                id: 5,
                firstName: "Maya",
                age: 24,
                city: "San Francisco",
                attractedTo: "Men",
                approachTip: "Let's talk about fitness and yoga",
                instagramHandle: "@maya_yoga",
                profileImage: "https://picsum.photos/400/400?random=105"
            ),
            AdaloMember(
                id: 6,
                firstName: "Alex",
                age: 29,
                city: "San Francisco",
                attractedTo: "Anyone",
                approachTip: "Music lover - let's jam!",
                instagramHandle: "@alex_music",
                profileImage: "https://picsum.photos/400/400?random=106"
            )
        ]
    }
}

// MARK: - Events Service
class AdaloEventsService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var events: [AdaloEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🔄 Fetching events from Events collection...")
        }
        
        networkService.fetchCollection(collectionName: "Events", responseType: AdaloEvent.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Failed to fetch events: \(error.localizedDescription)")
                            print("🔄 Using mock events fallback...")
                        }
                        // Load mock data when API fails
                        self?.events = self?.getMockEvents() ?? []
                    }
                },
                receiveValue: { [weak self] events in
                    self?.events = events
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully loaded \(events.count) events")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func createEvent(_ event: AdaloEvent) {
        networkService.createRecord(in: "Events", data: event)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newEvent in
                    self?.events.append(newEvent)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockEvents() -> [AdaloEvent] {
        return [
            AdaloEvent(
                id: 1,
                eventName: "Tech Meetup",
                venueName: "WeWork",
                eventLocation: "123 Main St, San Francisco, CA"
            ),
            AdaloEvent(
                id: 2,
                eventName: "Wine Tasting",
                venueName: "The Wine Bar",
                eventLocation: "456 Market St, San Francisco, CA"
            ),
            AdaloEvent(
                id: 3,
                eventName: "Yoga in the Park",
                venueName: "Golden Gate Park",
                eventLocation: "Golden Gate Park, San Francisco, CA"
            ),
            AdaloEvent(
                id: 4,
                eventName: "Art Gallery Opening",
                venueName: "Modern Art Space",
                eventLocation: "789 Mission St, San Francisco, CA"
            )
        ]
    }
}

// MARK: - Check-ins Service
class AdaloCheckInsService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var checkIns: [AdaloCheckIn] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchCheckIns() {
        isLoading = true
        errorMessage = nil
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🔄 Fetching check-ins from check_ins collection...")
        }
        
        networkService.fetchCollection(collectionName: "check_ins", responseType: AdaloCheckIn.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Failed to fetch check-ins: \(error.localizedDescription)")
                            print("🔄 Using mock check-ins fallback...")
                        }
                        // Load mock data when API fails
                        self?.checkIns = self?.getMockCheckIns() ?? []
                    }
                },
                receiveValue: { [weak self] checkIns in
                    self?.checkIns = checkIns
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully loaded \(checkIns.count) check-ins")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func checkIn(userId: Int, eventId: Int) {
        let checkIn = AdaloCheckIn(userId: userId, eventId: eventId)
        
        networkService.createRecord(in: "check_ins", data: checkIn)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newCheckIn in
                    self?.checkIns.append(newCheckIn)
                }
            )
            .store(in: &cancellables)
    }
    
    func getMembersAtEvent(_ eventId: Int) -> [AdaloMember] {
        // This would need to be implemented with a proper query
        // For now, return empty array
        return []
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockCheckIns() -> [AdaloCheckIn] {
        return [
            AdaloCheckIn(
                id: 1,
                userId: 123,
                eventId: 1
            ),
            AdaloCheckIn(
                id: 2,
                userId: 123,
                eventId: 2
            ),
            AdaloCheckIn(
                id: 3,
                userId: 456,
                eventId: 1
            )
        ]
    }
}

// MARK: - Conversations Service
class AdaloConversationsService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var conversations: [AdaloConversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchConversations(for userId: Int) {
        isLoading = true
        errorMessage = nil
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🔄 Fetching conversations for user \(userId)...")
        }
        
        networkService.fetchCollection(collectionName: "conversations", responseType: AdaloConversation.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Failed to fetch conversations: \(error.localizedDescription)")
                            print("🔄 Using mock conversations fallback...")
                        }
                        // Load mock data when API fails
                        self?.conversations = self?.getMockConversations(for: userId) ?? []
                    }
                },
                receiveValue: { [weak self] conversations in
                    // Filter conversations where user is a participant
                    let userConversations = conversations.filter { conversation in
                        conversation.participantOneId == userId || conversation.participantTwoId == userId
                    }
                    self?.conversations = userConversations
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully loaded \(userConversations.count) conversations from \(conversations.count) total")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func createConversation(participantOneId: Int, participantTwoId: Int) {
        let conversation = AdaloConversation(
            participantOneId: participantOneId,
            participantTwoId: participantTwoId
        )
        
        networkService.createRecord(in: "conversations", data: conversation)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newConversation in
                    self?.conversations.append(newConversation)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockConversations(for userId: Int) -> [AdaloConversation] {
        return [
            AdaloConversation(
                id: 1,
                participantOneId: userId,
                participantTwoId: 2,
                lastMessage: "Hey! How was the event last night?"
            ),
            AdaloConversation(
                id: 2,
                participantOneId: userId,
                participantTwoId: 3,
                lastMessage: "Thanks for the book recommendation!"
            ),
            AdaloConversation(
                id: 3,
                participantOneId: 4,
                participantTwoId: userId,
                lastMessage: "Let's grab coffee sometime this week?"
            )
        ]
    }
}

// MARK: - Messages Service
class AdaloMessagesService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var messages: [AdaloMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchMessages(for conversationId: Int) {
        isLoading = true
        errorMessage = nil
        
        if AdaloConfiguration.isLoggingEnabled {
            print("🔄 Fetching messages for conversation \(conversationId)...")
        }
        
        networkService.fetchCollection(collectionName: "messages", responseType: AdaloMessage.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                        if AdaloConfiguration.isLoggingEnabled {
                            print("❌ Failed to fetch messages: \(error.localizedDescription)")
                            print("🔄 Using mock messages fallback...")
                        }
                        // Load mock data when API fails
                        self?.messages = self?.getMockMessages(for: conversationId) ?? []
                    }
                },
                receiveValue: { [weak self] messages in
                    // Filter messages for this conversation
                    let conversationMessages = messages.filter { $0.conversationId == conversationId }
                        .sorted { $0.timestamp < $1.timestamp }
                    self?.messages = conversationMessages
                    if AdaloConfiguration.isLoggingEnabled {
                        print("✅ Successfully loaded \(conversationMessages.count) messages from \(messages.count) total")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func sendMessage(conversationId: Int, senderId: Int, messageText: String) {
        let message = AdaloMessage(
            conversationId: conversationId,
            senderId: senderId,
            messageText: messageText
        )
        
        networkService.createRecord(in: "messages", data: message)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newMessage in
                    self?.messages.append(newMessage)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockMessages(for conversationId: Int) -> [AdaloMessage] {
        // Generate different mock messages based on conversation ID
        switch conversationId {
        case 1:
            return [
                AdaloMessage(
                    id: 1,
                    conversationId: conversationId,
                    senderId: 2,
                    messageText: "Hey! How was the event last night?"
                ),
                AdaloMessage(
                    id: 2,
                    conversationId: conversationId,
                    senderId: 123,
                    messageText: "It was amazing! The live music was incredible 🎵"
                ),
                AdaloMessage(
                    id: 3,
                    conversationId: conversationId,
                    senderId: 2,
                    messageText: "I saw you dancing! You looked like you were having fun"
                )
            ]
        case 2:
            return [
                AdaloMessage(
                    id: 4,
                    conversationId: conversationId,
                    senderId: 3,
                    messageText: "Thanks for the book recommendation!"
                ),
                AdaloMessage(
                    id: 5,
                    conversationId: conversationId,
                    senderId: 123,
                    messageText: "Did you finish reading it already? 📚"
                ),
                AdaloMessage(
                    id: 6,
                    conversationId: conversationId,
                    senderId: 3,
                    messageText: "Almost! I couldn't put it down"
                )
            ]
        case 3:
            return [
                AdaloMessage(
                    id: 7,
                    conversationId: conversationId,
                    senderId: 4,
                    messageText: "Let's grab coffee sometime this week?"
                ),
                AdaloMessage(
                    id: 8,
                    conversationId: conversationId,
                    senderId: 123,
                    messageText: "Sounds great! How about Wednesday afternoon? ☕"
                )
            ]
        default:
            return [
                AdaloMessage(
                    id: 999,
                    conversationId: conversationId,
                    senderId: 123,
                    messageText: "Hello! This is a sample conversation."
                )
            ]
        }
    }
}

// MARK: - Image Fetching Service
class AdaloImageService: ObservableObject {
    private let networkService = AdaloNetworkService.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var allImages: [AdaloImageInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var progress: String = ""
    
    struct AdaloImageInfo {
        let url: String
        let filename: String?
        let size: Int?
        let width: Int?
        let height: Int?
        let source: String // "user", "event", "place", etc.
        let recordId: Int
        let blurHash: String?
    }
    
    func fetchAllImages() {
        isLoading = true
        errorMessage = nil
        allImages.removeAll()
        progress = "Starting image collection..."
        
        let group = DispatchGroup()
        var allImageInfos: [AdaloImageInfo] = []
        
        // Fetch from Users collection
        group.enter()
        progress = "Fetching user photos..."
        fetchUserImages { images in
            allImageInfos.append(contentsOf: images)
            group.leave()
        }
        
        // Fetch from Events collection
        group.enter()
        progress = "Fetching event images..."
        fetchEventImages { images in
            allImageInfos.append(contentsOf: images)
            group.leave()
        }
        
        // Fetch from Places collection
        group.enter()
        progress = "Fetching place images..."
        fetchPlaceImages { images in
            allImageInfos.append(contentsOf: images)
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.allImages = allImageInfos.sorted { $0.size ?? 0 > $1.size ?? 0 }
            self.isLoading = false
            self.progress = "Completed! Found \(allImageInfos.count) images"
            
            if AdaloConfiguration.isLoggingEnabled {
                print("📸 Collected \(allImageInfos.count) total images from all collections")
            }
        }
    }
    
    private func fetchUserImages(completion: @escaping ([AdaloImageInfo]) -> Void) {
        networkService.fetchCollection(collectionName: "Users", responseType: AdaloUser.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        self?.errorMessage = "Failed to fetch user images: \(error.localizedDescription)"
                        // Return mock data if API fails
                        completion(self?.getMockUserImages() ?? [])
                    }
                },
                receiveValue: { users in
                    let images = users.compactMap { user -> AdaloImageInfo? in
                        guard let photoString = user.profilePhoto,
                              !photoString.isEmpty,
                              let imageInfo = self.parseImageString(photoString) else { return nil }
                        
                        return AdaloImageInfo(
                            url: imageInfo.url,
                            filename: imageInfo.filename,
                            size: imageInfo.size,
                            width: imageInfo.width,
                            height: imageInfo.height,
                            source: "user",
                            recordId: user.id,
                            blurHash: imageInfo.blurHash
                        )
                    }
                    completion(images)
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchEventImages(completion: @escaping ([AdaloImageInfo]) -> Void) {
        networkService.fetchCollection(collectionName: "Events", responseType: AdaloEvent.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        self?.errorMessage = "Failed to fetch event images: \(error.localizedDescription)"
                        // Return mock data if API fails
                        completion(self?.getMockEventImages() ?? [])
                    }
                },
                receiveValue: { events in
                    let images = events.compactMap { event -> AdaloImageInfo? in
                        guard let imageString = event.image,
                              !imageString.isEmpty,
                              let imageInfo = self.parseImageString(imageString) else { return nil }
                        
                        return AdaloImageInfo(
                            url: imageInfo.url,
                            filename: imageInfo.filename,
                            size: imageInfo.size,
                            width: imageInfo.width,
                            height: imageInfo.height,
                            source: "event",
                            recordId: event.id,
                            blurHash: imageInfo.blurHash
                        )
                    }
                    completion(images)
                }
            )
            .store(in: &cancellables)
    }
    
    private func fetchPlaceImages(completion: @escaping ([AdaloImageInfo]) -> Void) {
        networkService.fetchCollection(collectionName: "Places", responseType: AdaloPlace.self)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        self?.errorMessage = "Failed to fetch place images: \(error.localizedDescription)"
                        // Return mock data if API fails
                        completion(self?.getMockPlaceImages() ?? [])
                    }
                },
                receiveValue: { places in
                    let images = places.compactMap { place -> AdaloImageInfo? in
                        guard let imageString = place.placeImage,
                              !imageString.isEmpty,
                              let imageInfo = self.parseImageString(imageString) else { return nil }
                        
                        return AdaloImageInfo(
                            url: imageInfo.url,
                            filename: imageInfo.filename,
                            size: imageInfo.size,
                            width: imageInfo.width,
                            height: imageInfo.height,
                            source: "place",
                            recordId: place.id,
                            blurHash: imageInfo.blurHash
                        )
                    }
                    completion(images)
                }
            )
            .store(in: &cancellables)
    }
    
    private func parseImageString(_ imageString: String) -> (url: String, filename: String?, size: Int?, width: Int?, height: Int?, blurHash: String?)? {
        // Parse the JSON-like string format from Adalo
        // Example: "{'url':'abc.jpeg','size':123,'width':100,'height':200,'filename':'file.jpeg'}"
        
        do {
            // Convert single quotes to double quotes for valid JSON
            let jsonString = imageString.replacingOccurrences(of: "'", with: "\"")
            guard let data = jsonString.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            guard let url = json["url"] as? String else { return nil }
            
            let filename = json["filename"] as? String
            let size = (json["size"] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let width = (json["width"] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let height = (json["height"] as? Int).flatMap { $0 > 0 ? $0 : nil }
            
            // Extract blurHash from metadata if available
            var blurHash: String?
            if let metadata = json["metadata"] as? [String: Any] {
                blurHash = metadata["blurHash"] as? String
            }
            
            // Construct full URL if it's a relative path
            let fullURL = url.hasPrefix("http") ? url : "https://api.adalo.com/v0/\(url)"
            
            return (fullURL, filename, size, width, height, blurHash)
        } catch {
            print("Failed to parse image string: \(imageString)")
            return nil
        }
    }
    
    // MARK: - Export Functions
    func exportImageURLs() -> String {
        let urls = allImages.map { $0.url }
        return urls.joined(separator: "\n")
    }
    
    func exportImageInfo() -> String {
        return allImages.map { imageInfo in
            """
            URL: \(imageInfo.url)
            Source: \(imageInfo.source) (ID: \(imageInfo.recordId))
            Filename: \(imageInfo.filename ?? "N/A")
            Size: \(imageInfo.size?.formatted() ?? "N/A") bytes
            Dimensions: \(imageInfo.width ?? 0) x \(imageInfo.height ?? 0)
            BlurHash: \(imageInfo.blurHash ?? "N/A")
            ---
            """
        }.joined(separator: "\n")
    }
    
    func getTotalImageSize() -> Int {
        return allImages.compactMap { $0.size }.reduce(0, +)
    }
    
    func getImageCount(by source: String) -> Int {
        return allImages.filter { $0.source == source }.count
    }
    
    // MARK: - Mock Data for API Failures
    private func getMockUserImages() -> [AdaloImageInfo] {
        return [
            AdaloImageInfo(
                url: "https://picsum.photos/400/400?random=1",
                filename: "profile_1.jpg",
                size: 125000,
                width: 400,
                height: 400,
                source: "user",
                recordId: 1,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            ),
            AdaloImageInfo(
                url: "https://picsum.photos/400/400?random=2",
                filename: "profile_2.jpg",
                size: 98000,
                width: 400,
                height: 400,
                source: "user",
                recordId: 2,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            ),
            AdaloImageInfo(
                url: "https://picsum.photos/400/400?random=3",
                filename: "profile_3.jpg",
                size: 110000,
                width: 400,
                height: 400,
                source: "user",
                recordId: 3,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            )
        ]
    }
    
    private func getMockEventImages() -> [AdaloImageInfo] {
        return [
            AdaloImageInfo(
                url: "https://picsum.photos/600/400?random=10",
                filename: "event_1.jpg",
                size: 185000,
                width: 600,
                height: 400,
                source: "event",
                recordId: 10,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            ),
            AdaloImageInfo(
                url: "https://picsum.photos/600/400?random=11",
                filename: "event_2.jpg",
                size: 205000,
                width: 600,
                height: 400,
                source: "event",
                recordId: 11,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            )
        ]
    }
    
    private func getMockPlaceImages() -> [AdaloImageInfo] {
        return [
            AdaloImageInfo(
                url: "https://picsum.photos/500/600?random=20",
                filename: "place_1.jpg",
                size: 165000,
                width: 500,
                height: 600,
                source: "place",
                recordId: 20,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            ),
            AdaloImageInfo(
                url: "https://picsum.photos/500/600?random=21",
                filename: "place_2.jpg",
                size: 175000,
                width: 500,
                height: 600,
                source: "place",
                recordId: 21,
                blurHash: "LKO2?V%2Tw=w]~RBVZRi};RPxuwH"
            )
        ]
    }
}

// MARK: - Image Download Utility
class AdaloImageDownloader: ObservableObject {
    static let shared = AdaloImageDownloader()
    
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""
    @Published var isDownloading = false
    @Published var downloadedImages: [(filename: String, localURL: URL)] = []
    
    private init() {}
    
    /// Downloads all images from Adalo to device storage
    /// - Parameter completion: Called when all downloads complete with success count and errors
    func downloadAllImages(completion: @escaping (Int, [String]) -> Void) {
        let imageService = AdaloImageService()
        isDownloading = true
        downloadProgress = 0.0
        downloadedImages.removeAll()
        downloadStatus = "Fetching image list..."
        
        // First fetch all image info
        imageService.fetchAllImages()
        
        // Wait for fetch to complete, then start downloads
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if !imageService.isLoading && !imageService.allImages.isEmpty {
                timer.invalidate()
                self.startDownloads(images: imageService.allImages, completion: completion)
            } else if !imageService.isLoading && imageService.allImages.isEmpty {
                timer.invalidate()
                self.isDownloading = false
                self.downloadStatus = "No images found"
                completion(0, ["No images found in Adalo collections"])
            }
        }
    }
    
    private func startDownloads(images: [AdaloImageService.AdaloImageInfo], completion: @escaping (Int, [String]) -> Void) {
        let totalImages = images.count
        var downloadedCount = 0
        var errors: [String] = []
        let downloadQueue = DispatchQueue(label: "image.download.queue", qos: .background)
        let group = DispatchGroup()
        
        downloadStatus = "Starting downloads..."
        
        // Create downloads directory
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(0, ["Failed to access documents directory"])
            return
        }
        
        let imagesDir = documentsDir.appendingPathComponent("AdaloImages")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        for (index, imageInfo) in images.enumerated() {
            group.enter()
            
            downloadQueue.async {
                self.downloadSingleImage(imageInfo: imageInfo, to: imagesDir) { success, localURL, error in
                    DispatchQueue.main.async {
                        if success, let url = localURL {
                            downloadedCount += 1
                            let filename = imageInfo.filename ?? "image_\(imageInfo.recordId)_\(imageInfo.source).jpg"
                            self.downloadedImages.append((filename: filename, localURL: url))
                        } else if let error = error {
                            errors.append("Failed to download \(imageInfo.filename ?? "image"): \(error)")
                        }
                        
                        let progress = totalImages > 0 ? Double(index + 1) / Double(totalImages) : 0.0
                        self.downloadProgress = progress.isNaN ? 0.0 : progress
                        self.downloadStatus = "Downloaded \(downloadedCount)/\(totalImages) images"
                        
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            self.isDownloading = false
            self.downloadStatus = "Completed: \(downloadedCount) images downloaded"
            if AdaloConfiguration.isLoggingEnabled {
                print("📥 Downloaded \(downloadedCount) images to: \(imagesDir.path)")
            }
            completion(downloadedCount, errors)
        }
    }
    
    private func downloadSingleImage(imageInfo: AdaloImageService.AdaloImageInfo, to directory: URL, completion: @escaping (Bool, URL?, String?) -> Void) {
        guard let url = URL(string: imageInfo.url) else {
            completion(false, nil, "Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(false, nil, error.localizedDescription)
                return
            }
            
            guard let data = data else {
                completion(false, nil, "No data received")
                return
            }
            
            // Create filename
            let filename = imageInfo.filename ?? "image_\(imageInfo.recordId)_\(imageInfo.source).jpg"
            let localURL = directory.appendingPathComponent(filename)
            
            do {
                try data.write(to: localURL)
                completion(true, localURL, nil)
            } catch {
                completion(false, nil, "Failed to save: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    /// Get the local documents directory path for downloaded images
    func getDownloadDirectory() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDir.appendingPathComponent("AdaloImages")
    }
    
    /// Clear all downloaded images
    func clearDownloadedImages() {
        guard let downloadDir = getDownloadDirectory() else { return }
        
        try? FileManager.default.removeItem(at: downloadDir)
        downloadedImages.removeAll()
        downloadStatus = "Cleared downloaded images"
    }
    
    /// Get total size of downloaded images
    func getDownloadedImagesSize() -> Int64 {
        guard let downloadDir = getDownloadDirectory() else { return 0 }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: downloadDir, includingPropertiesForKeys: [.fileSizeKey])
            
            let totalSize = try fileURLs.reduce(Int64(0)) { total, fileURL in
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(resourceValues.fileSize ?? 0)
                return total + fileSize
            }
            
            return totalSize
        } catch {
            return 0
        }
    }
} 