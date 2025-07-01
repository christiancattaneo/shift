import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct MembersView: View {
    @State private var searchText = ""
    @ObservedObject private var membersService = FirebaseMembersService.shared
    
    // Computed property for filtered members  
    var filteredMembers: [FirebaseMember] {
        if searchText.isEmpty {
            return membersService.members
        } else {
            return membersService.members.filter { 
                $0.firstName.localizedCaseInsensitiveContains(searchText) ||
                ($0.city?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                ($0.attractedTo?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    // Define grid layout
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    // Test Image View - TEMPORARY FOR DEBUGGING
                    TestFirebaseImageView()
                    
                    // TEMPORARY: Test if manually constructed URLs work for actual members
                    VStack(spacing: 10) {
                        Text("🧪 MANUAL URL CONSTRUCTION TEST")
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        HStack(spacing: 12) {
                            ForEach(filteredMembers.prefix(2), id: \.uniqueID) { member in
                                VStack(spacing: 4) {
                                    let testURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/\(member.id ?? member.userId ?? "unknown")_1751052272118.jpeg")
                                    
                                    AsyncImage(url: testURL) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .frame(width: 50, height: 50)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 50, height: 50)
                                                .clipShape(Circle())
                                        case .failure:
                                            Circle()
                                                .fill(Color.red.opacity(0.3))
                                                .frame(width: 50, height: 50)
                                                .overlay(Text("❌").font(.caption))
                                        @unknown default:
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 50, height: 50)
                                        }
                                    }
                                    Text(member.firstName)
                                        .font(.caption2)
                                    Text("ID: \(member.id ?? member.userId ?? "nil")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Text("Testing if Firebase Storage URLs exist for member IDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(12)
                    
                    // Header
                    HStack {
                        Text("Members")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .onTapGesture {
                                print("👥 MEMBERS TITLE TAPPED - UI should be responsive")
                            }
                        Spacer()
                        
                        // Debug refresh button
                        Button("🔄") {
                            print("🔄 Manual refresh triggered")
                            print("🔄 Manual refresh: Thread=MAIN")
                            membersService.refreshMembers()
                        }
                        .font(.title2)
                        .onAppear {
                            print("🔄 Refresh button appeared")
                        }
                        
                        // Debug image check button
                        Button("🖼️") {
                            print("🖼️ === CURRENT MEMBERS IMAGE STATUS ===")
                            for member in membersService.members {
                                print("🖼️ \(member.firstName):")
                                print("  - profileImageUrl: \(member.profileImageUrl ?? "nil")")
                                print("  - firebaseImageUrl: \(member.firebaseImageUrl ?? "nil")")
                                print("  - profileImage: \(member.profileImage ?? "nil")")
                                print("  - computed URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                            }
                            print("🖼️ =====================================")
                        }
                        .font(.title2)
                        .foregroundColor(.orange)
                        
                        // Fix missing image URLs button
                        Button("🔧") {
                            print("🔧 Attempting to fix missing image URLs...")
                            Task {
                                await fixMissingImageURLs()
                            }
                        }
                        .font(.title2)
                        .foregroundColor(.red)
                        
                        // Inspect Firestore documents button
                        Button("🔍") {
                            print("🔍 Inspecting Firestore document structure...")
                            let db = Firestore.firestore()
                            
                            // Check first few members
                            for member in Array(membersService.members.prefix(3)) {
                                guard let memberId = member.id else { continue }
                                
                                db.collection("users").document(memberId).getDocument { document, error in
                                    if let document = document, document.exists {
                                        let data = document.data() ?? [:]
                                        print("🔍 === MEMBER: \(member.firstName) ===")
                                        print("🔍 All fields: \(data.keys.sorted())")
                                        print("🔍 =================================")
                                    }
                                }
                            }
                        }
                        .font(.title2)
                        .foregroundColor(.blue)
                        
                        // NEW: Firebase Storage Inspector Button
                        Button("📁") {
                            print("📁 INSPECTING FIREBASE STORAGE...")
                            inspectFirebaseStorage()
                        }
                        .font(.title2)
                        .foregroundColor(.purple)
                        
                        // NEW: Smart Image Mapping Script
                        Button("🔗") {
                            print("🔗 STARTING SMART IMAGE MAPPING...")
                            createImageMapping()
                        }
                        .font(.title2)
                        .foregroundColor(.green)
                        
                        // BETTER: Cloud Function Trigger
                        Button("☁️") {
                            print("☁️ TRIGGERING CLOUD FUNCTION...")
                            triggerImageMappingCloudFunction()
                        }
                        .font(.title2)
                        .foregroundColor(.orange)
                        
                        // SAFETY: Backup All Storage Data
                        Button("💾") {
                            print("💾 BACKING UP ALL FIREBASE STORAGE DATA...")
                            backupAllStorageData()
                        }
                        .font(.title2)
                        .foregroundColor(.red)
                        
                        Image("shiftlogo") // Assuming logo is in assets
                            .resizable()
                            .scaledToFit()
                            .frame(height: 30)
                            .onTapGesture {
                                print("👥 LOGO TAPPED - UI should be responsive")
                            }
                    }
                    .onAppear {
                        print("👥 Header appeared")
                    }
                    
                    Text("Explore single members")
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            print("👥 SUBTITLE TAPPED - UI should be responsive")
                        }

                    // Search Bar Placeholder
                    TextField("Search Members...", text: $searchText)
                        .padding(10)
                        .padding(.horizontal, 25) // Indent text for icon space
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 8)
                                    .onTapGesture {
                                        print("👥 SEARCH ICON TAPPED - UI should be responsive")
                                    }
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        print("👥 CLEAR SEARCH TAPPED")
                                        self.searchText = ""
                                    }) {
                                        Image(systemName: "multiply.circle.fill")
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                    .onAppear {
                                        print("👥 Clear search button appeared")
                                    }
                                }
                            }
                        )
                        .padding(.top, 5)
                        .onAppear {
                            print("👥 Search bar appeared")
                        }
                        .onChange(of: searchText) { oldValue, newValue in
                            print("👥 Search text changed: '\(oldValue)' -> '\(newValue)'")
                        }

                    // Members Grid
                    if membersService.isLoading {
                        VStack {
                            ProgressView("Loading members from Firebase...")
                                .progressViewStyle(CircularProgressViewStyle())
                                .onTapGesture {
                                    print("👥 LOADING PROGRESS TAPPED - UI should be responsive")
                                }
                            Text("Fetching real data...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                                .onTapGesture {
                                    print("👥 LOADING TEXT TAPPED - UI should be responsive")
                                }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            print("👥 Loading state appeared")
                        }
                    } else if filteredMembers.isEmpty {
                        VStack {
                            if membersService.errorMessage != nil {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        print("👥 ERROR ICON TAPPED - UI should be responsive")
                                    }
                                Text("Unable to load members")
                                    .font(.headline)
                                    .onTapGesture {
                                        print("👥 ERROR TEXT TAPPED - UI should be responsive")
                                    }
                                Text("Check your internet connection")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        print("👥 ERROR SUBTITLE TAPPED - UI should be responsive")
                                    }
                            } else {
                                Image(systemName: "person.3")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS ICON TAPPED - UI should be responsive")
                                    }
                                Text("No members found")
                                    .font(.headline)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS TEXT TAPPED - UI should be responsive")
                                    }
                                Text("Try adjusting your search")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onTapGesture {
                                        print("👥 NO MEMBERS SUBTITLE TAPPED - UI should be responsive")
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            print("👥 Empty state appeared")
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredMembers, id: \.uniqueID) { member in
                                MemberCardView(member: member)
                                    .onTapGesture {
                                        print("👥 MEMBER CARD TAPPED: \(member.firstName) - UI should be responsive")
                                    }
                            }
                        }
                        .onAppear {
                            print("👥 Members grid appeared with \(filteredMembers.count) members")
                        }
                        
                                                    // Data source indicator
                            VStack(spacing: 5) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .onTapGesture {
                                            print("👥 SUCCESS ICON TAPPED - UI should be responsive")
                                        }
                                    Text("Loaded \(filteredMembers.count) members from Firebase")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .onTapGesture {
                                            print("👥 SUCCESS TEXT TAPPED - UI should be responsive")
                                        }
                                }
                                
                                // FORCE REFRESH BUTTON after migration  
                                Button("🔄 Force Refresh Data") {
                                    print("🔄 FORCE REFRESH TAPPED - Clearing cache and fetching fresh data")
                                    Task {
                                        await forceRefreshFromFirestore()
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                            
                            // Debug info
                            Text("Total in service: \(membersService.members.count) • Loading: \(membersService.isLoading)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .onTapGesture {
                                    print("👥 DEBUG INFO TAPPED - UI should be responsive")
                                }
                        }
                        .padding(.top, 10)
                        .onAppear {
                            print("👥 Data source indicator appeared")
                        }
                    }
                    
                    // Error message
                    if let errorMessage = membersService.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        print("👥 ERROR ICON TAPPED - UI should be responsive")
                                    }
                                Text("Connection Error")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .onTapGesture {
                                        print("👥 ERROR TITLE TAPPED - UI should be responsive")
                                    }
                            }
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .onTapGesture {
                                    print("👥 ERROR MESSAGE TAPPED - UI should be responsive")
                                }
                            
                            Button("Retry") {
                                print("👥 RETRY BUTTON TAPPED")
                                print("👥 RETRY: Thread=MAIN")
                                membersService.refreshMembers()
                            }
                            .padding(.top, 5)
                            .buttonStyle(.bordered)
                            .onAppear {
                                print("👥 Retry button appeared")
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .onAppear {
                            print("👥 Error message appeared: \(errorMessage)")
                        }
                    }

                }
                .padding()
                .onAppear {
                    print("👥 Main VStack appeared")
                }
            }
        .onAppear {
            print("👥 MembersView onAppear - calling fetchMembers")
            print("👥 MembersView onAppear: Thread=MAIN")
            membersService.fetchMembers()
        }
        .refreshable {
            print("👥 Pull to refresh triggered")
            print("👥 Pull to refresh: Thread=MAIN")
            membersService.refreshMembers()
        }
        .onTapGesture {
            print("👥 MEMBERS VIEW BACKGROUND TAPPED - UI should be responsive")
        }
        .gesture(
            // Add a drag gesture to detect if gestures are working
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    print("👥 DRAG GESTURE DETECTED on MembersView - direction: \(value.translation)")
                }
        )
    }
    
    // MARK: - Force Refresh From Firestore (Clear Cache)
    private func forceRefreshFromFirestore() async {
        print("🔄 FORCE REFRESH: Clearing all cached data and fetching fresh from Firestore")
        
        await MainActor.run {
            // Clear the members service cache
            membersService.members = []
            membersService.isLoading = true
            membersService.errorMessage = nil
        }
        
        // Wait a moment for UI to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Force fresh fetch from Firestore
        await MainActor.run {
            print("🔄 Triggering fresh Firestore fetch...")
            membersService.fetchMembers()
        }
        
        // Additional refresh after 2 seconds to ensure data is loaded
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        await MainActor.run {
            print("🔄 Secondary refresh to ensure fresh data...")
            membersService.refreshMembers()
        }
    }
    
    // MARK: - Fix Missing Image URLs Function
    private func fixMissingImageURLs() async {
        print("🔧 Starting image URL fix process...")
        
        await MainActor.run {
            // Run this on main actor to avoid concurrency issues
            let db = Firestore.firestore()
            
            for member in membersService.members {
                // Skip if already has Firebase Storage URL
                if member.profileImageUrl != nil || member.firebaseImageUrl != nil {
                    print("✅ \(member.firstName) already has Firebase Storage URL")
                    continue
                }
                
                guard let memberId = member.id ?? member.userId else {
                    print("❌ No ID found for \(member.firstName)")
                    continue
                }
                
                // Check if member document has an 'adaloId' field
                db.collection("users").document(memberId).getDocument { document, error in
                    if let document = document, document.exists {
                        let data = document.data()
                        print("🔍 Document data for \(member.firstName): \(data?.keys.joined(separator: ", ") ?? "no keys")")
                        
                        // Look for adaloId or similar fields
                        if let adaloId = data?["adaloId"] as? Int {
                            print("✅ Found adaloId for \(member.firstName): \(adaloId)")
                            let imageURL = "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/\(adaloId)_1751051525259.jpeg"
                            
                            // Update document with proper image URL
                            db.collection("users").document(memberId).updateData([
                                "profileImageUrl": imageURL,
                                "firebaseImageUrl": imageURL,
                                "updatedAt": Timestamp()
                            ]) { error in
                                if let error = error {
                                    print("❌ Failed to update \(member.firstName): \(error)")
                                } else {
                                    print("✅ Updated \(member.firstName) with image URL")
                                }
                            }
                        } else {
                            print("❌ No adaloId found for \(member.firstName)")
                        }
                    }
                }
            }
            
            // Refresh after a delay to allow updates to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("🔧 Refreshing members after URL fixes...")
                self.membersService.refreshMembers()
            }
        }
    }
    
    // MARK: - Firebase Storage Inspector
    private func inspectFirebaseStorage() {
        print("📁 Starting Firebase Storage inspection...")
        let storage = Storage.storage()
        
        // Inspect profile_images folder
        let profileImagesRef = storage.reference().child("profile_images")
        profileImagesRef.listAll { result, error in
            if let error = error {
                print("📁 ❌ Error listing profile_images: \(error)")
                return
            }
            
            print("📁 === PROFILE IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("📁 Profile Image: \(item.name)")
                
                // Get download URL
                item.downloadURL { url, error in
                    if let url = url {
                        print("📁   URL: \(url.absoluteString)")
                    }
                }
            }
            print("📁 Total profile images: \(result?.items.count ?? 0)")
            print("📁 ===========================")
        }
        
        // Inspect event_images folder
        let eventImagesRef = storage.reference().child("event_images")
        eventImagesRef.listAll { result, error in
            if let error = error {
                print("📁 ❌ Error listing event_images: \(error)")
                return
            }
            
            print("📁 === EVENT IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("📁 Event Image: \(item.name)")
            }
            print("📁 Total event images: \(result?.items.count ?? 0)")
            print("📁 ==========================")
        }
        
        // Inspect place_images folder
        let placeImagesRef = storage.reference().child("place_images")
        placeImagesRef.listAll { result, error in
            if let error = error {
                print("📁 ❌ Error listing place_images: \(error)")
                return
            }
            
            print("📁 === PLACE IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("📁 Place Image: \(item.name)")
            }
            print("📁 Total place images: \(result?.items.count ?? 0)")
            print("📁 ==========================")
        }
    }
    
    // MARK: - Smart Image Mapping Script
    private func createImageMapping() {
        print("🔗 Creating intelligent image mapping...")
        let storage = Storage.storage()
        let db = Firestore.firestore()
        
        // Step 1: Get all profile images from Firebase Storage
        let profileImagesRef = storage.reference().child("profile_images")
        profileImagesRef.listAll { result, error in
            if let error = error {
                print("🔗 ❌ Error listing profile images: \(error)")
                return
            }
            
            guard let items = result?.items else {
                print("🔗 ❌ No profile images found")
                return
            }
            
            print("🔗 Found \(items.count) profile images in Firebase Storage")
            
            // Step 2: Extract Adalo IDs and build mapping
            var adaloIdToImages: [String: [StorageReference]] = [:]
            
            for item in items {
                // Extract Adalo ID from filename (e.g., "100_175105227211.jpeg" -> "100")
                let filename = item.name
                if let adaloId = filename.components(separatedBy: "_").first,
                   Int(adaloId) != nil { // Verify it's a number
                    
                    if adaloIdToImages[adaloId] == nil {
                        adaloIdToImages[adaloId] = []
                    }
                    adaloIdToImages[adaloId]?.append(item)
                }
            }
            
            print("🔗 Extracted \(adaloIdToImages.count) unique Adalo IDs: \(Array(adaloIdToImages.keys).sorted())")
            
            // Step 3: Update Firestore documents
            self.updateFirestoreWithImageMappings(adaloIdToImages: adaloIdToImages, db: db)
        }
    }
    
    private func updateFirestoreWithImageMappings(adaloIdToImages: [String: [StorageReference]], db: Firestore) {
        print("🔗 Updating Firestore documents with image URLs...")
        
        // Get all users from Firestore
        db.collection("users").getDocuments { querySnapshot, error in
            if let error = error {
                print("🔗 ❌ Error fetching users: \(error)")
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                print("🔗 ❌ No users found in Firestore")
                return
            }
            
            print("🔗 Found \(documents.count) users in Firestore")
            
            var updatedCount = 0
            let dispatchGroup = DispatchGroup()
            
            for document in documents {
                let data = document.data()
                let firstName = data["firstName"] as? String ?? "Unknown"
                
                // Try multiple strategies to find the Adalo ID
                var adaloId: String?
                
                // Strategy 1: Check if adaloId field exists
                if let existingAdaloId = data["adaloId"] as? Int {
                    adaloId = String(existingAdaloId)
                    print("🔗 Found existing adaloId for \(firstName): \(adaloId!)")
                }
                // Strategy 2: Check if originalId field exists
                else if let originalId = data["originalId"] as? Int {
                    adaloId = String(originalId)
                    print("🔗 Found originalId for \(firstName): \(adaloId!)")
                }
                // Strategy 3: Try to infer from other numeric fields
                else {
                    // Look for any numeric field that might be the original ID
                    for (key, value) in data {
                        if let intValue = value as? Int, intValue > 0 && intValue < 10000 {
                            // Check if this ID has images in storage
                            if adaloIdToImages[String(intValue)] != nil {
                                adaloId = String(intValue)
                                print("🔗 Inferred adaloId for \(firstName) from \(key): \(adaloId!)")
                                break
                            }
                        }
                    }
                }
                
                // If we found an Adalo ID and it has images, update the document
                if let adaloId = adaloId,
                   let imageRefs = adaloIdToImages[adaloId],
                   let firstImage = imageRefs.first {
                    
                    dispatchGroup.enter()
                    
                    // Get the download URL for the first (latest) image
                    firstImage.downloadURL { url, error in
                        defer { dispatchGroup.leave() }
                        
                        if let error = error {
                            print("🔗 ❌ Error getting download URL for \(firstName): \(error)")
                            return
                        }
                        
                        guard let url = url else {
                            print("🔗 ❌ No download URL for \(firstName)")
                            return
                        }
                        
                        // Update Firestore document with image URLs
                        let updateData: [String: Any] = [
                            "profileImageUrl": url.absoluteString,
                            "firebaseImageUrl": url.absoluteString,
                            "adaloId": Int(adaloId) ?? 0,
                            "profileImageMappedAt": Timestamp()
                        ]
                        
                        document.reference.updateData(updateData) { error in
                            if let error = error {
                                print("🔗 ❌ Error updating \(firstName): \(error)")
                            } else {
                                print("🔗 ✅ Updated \(firstName) with image URL: \(url.absoluteString)")
                                updatedCount += 1
                            }
                        }
                    }
                } else {
                    print("🔗 ⚠️ No image mapping found for \(firstName)")
                }
            }
            
            // Wait for all updates to complete
            dispatchGroup.notify(queue: .main) {
                print("🔗 🎉 MAPPING COMPLETE! Updated \(updatedCount) users with profile images")
                print("🔗 Refreshing members list...")
                self.membersService.refreshMembers()
            }
        }
    }
    
    // MARK: - Better: Cloud Function Approach
    private func triggerImageMappingCloudFunction() {
        print("☁️ Calling Cloud Function for server-side image mapping...")
        
        // Call your Cloud Function endpoint
        let url = URL(string: "https://us-central1-shift-12948.cloudfunctions.net/mapProfileImages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["trigger": "mapImages", "timestamp": Date().timeIntervalSince1970]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("☁️ ❌ Cloud Function error: \(error)")
                    return
                }
                
                print("☁️ ✅ Cloud Function completed successfully")
                print("☁️ Refreshing members list...")
                self.membersService.refreshMembers()
            }
        }.resume()
    }
    
    // MARK: - SAFETY: Backup All Storage Data
    private func backupAllStorageData() {
        print("💾 BACKING UP ALL FIREBASE STORAGE DATA...")
        let storage = Storage.storage()
        
        // Inspect profile_images folder
        let profileImagesRef = storage.reference().child("profile_images")
        profileImagesRef.listAll { result, error in
            if let error = error {
                print("💾 ❌ Error listing profile_images: \(error)")
                return
            }
            
            print("💾 === PROFILE IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("💾 Profile Image: \(item.name)")
                
                // Get download URL
                item.downloadURL { url, error in
                    if let url = url {
                        print("💾   URL: \(url.absoluteString)")
                    }
                }
            }
            print("💾 Total profile images: \(result?.items.count ?? 0)")
            print("💾 ===========================")
        }
        
        // Inspect event_images folder
        let eventImagesRef = storage.reference().child("event_images")
        eventImagesRef.listAll { result, error in
            if let error = error {
                print("💾 ❌ Error listing event_images: \(error)")
                return
            }
            
            print("💾 === EVENT IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("💾 Event Image: \(item.name)")
            }
            print("💾 Total event images: \(result?.items.count ?? 0)")
            print("💾 ==========================")
        }
        
        // Inspect place_images folder
        let placeImagesRef = storage.reference().child("place_images")
        placeImagesRef.listAll { result, error in
            if let error = error {
                print("💾 ❌ Error listing place_images: \(error)")
                return
            }
            
            print("💾 === PLACE IMAGES FOUND ===")
            for item in result?.items ?? [] {
                print("💾 Place Image: \(item.name)")
            }
            print("�� Total place images: \(result?.items.count ?? 0)")
            print("💾 ==========================")
        }
    }
}

// Card View for each member
struct MemberCardView: View {
    let member: FirebaseMember

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Image with detailed logging
            AsyncImage(url: member.profileImageURL) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                        VStack {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .clipped()
                case .failure(let error):
                    ZStack {
                        Rectangle()
                            .fill(Color.red.opacity(0.2))
                            .frame(height: 150)
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundColor(.red)
                            Text("Failed to load")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .onAppear {
                        print("❌ Image failed to load for \(member.firstName): \(error.localizedDescription)")
                        print("❌ Failed URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                    }
                @unknown default:
                    ZStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 150)
                        Image(systemName: "questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                // ENHANCED DEBUG LOGGING FOR MEMBER IMAGES
                print("🔍 === MEMBER IMAGE DEBUG: \(member.firstName) ===")
                print("🔍 profileImageUrl: \(member.profileImageUrl ?? "nil")")
                print("🔍 firebaseImageUrl: \(member.firebaseImageUrl ?? "nil")")
                print("🔍 profileImage (legacy): \(member.profileImage ?? "nil")")
                print("🔍 computed profileImageURL: \(member.profileImageURL?.absoluteString ?? "nil")")
                print("🔍 member.id: \(member.id ?? "nil")")
                print("🔍 member.userId: \(member.userId ?? "nil")")
                print("🔍 ==========================================")
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Name and Age
                HStack {
                    Text(member.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            print("👥 MEMBER NAME TAPPED: \(member.firstName) - UI should be responsive")
                        }
                    
                    Spacer()
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                print("👥 MEMBER AGE TAPPED: \(member.firstName) - UI should be responsive")
                            }
                    }
                }
                
                // City
                if let city = member.city, !city.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        print("👥 MEMBER CITY TAPPED: \(member.firstName) - UI should be responsive")
                    }
                }
                
                // Attracted To
                if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                    Text("Attracted to: \(attractedTo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .onTapGesture {
                            print("👥 MEMBER ATTRACTION TAPPED: \(member.firstName) - UI should be responsive")
                        }
                }
                
                // Approach Tip
                if let approachTip = member.approachTip, !approachTip.isEmpty {
                    Text(approachTip)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .padding(.top, 2)
                        .onTapGesture {
                            print("👥 MEMBER APPROACH TIP TAPPED: \(member.firstName) - UI should be responsive")
                        }
                }
                
                // Instagram Handle
                if let instagram = member.instagramHandle, !instagram.isEmpty {
                    HStack {
                        Image(systemName: "camera")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("@\(instagram)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                    .padding(.top, 2)
                    .onTapGesture {
                        print("👥 MEMBER INSTAGRAM TAPPED: \(member.firstName) - UI should be responsive")
                    }
                }
                
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .onTapGesture {
                            print("👥 MEMBER CHEVRON TAPPED: \(member.firstName) - UI should be responsive")
                        }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color(.systemGray6)) // Background for the card
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            print("👥 MEMBER CARD BACKGROUND TAPPED: \(member.firstName) - UI should be responsive")
        }
    }
}

// MARK: - TEST IMAGE VIEW
struct TestFirebaseImageView: View {
    // Test with real images from all three Firebase Storage collections
    let profileImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/100_1751052272118.jpeg")
    let eventImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/event_images/127_1751052295829.png")
    let placeImageURL = URL(string: "https://storage.googleapis.com/shift-12948.firebasestorage.app/place_images/10_1751052347060.jpeg")
    
    var body: some View {
        VStack(spacing: 10) {
            Text("🧪 FIREBASE IMAGE COLLECTION TEST")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack(spacing: 12) {
                // Profile image test (User ID: 100)
                VStack(spacing: 4) {
                    AsyncImage(url: profileImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .onAppear {
                                    print("✅ PROFILE IMAGE LOADED! (User ID: 100)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "person.crop.circle.fill.badge.xmark")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Profile image failed: \(error)")
                            }
                        @unknown default:
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("👤 Profile")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Event image test (Event ID: 127)
                VStack(spacing: 4) {
                    AsyncImage(url: eventImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onAppear {
                                    print("✅ EVENT IMAGE LOADED! (Event ID: 127)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Event image failed: \(error)")
                            }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("🎉 Event")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 127")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Place image test (Place ID: 10)
                VStack(spacing: 4) {
                    AsyncImage(url: placeImageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 70, height: 70)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onAppear {
                                    print("✅ PLACE IMAGE LOADED! (Place ID: 10)")
                                }
                        case .failure(let error):
                            VStack {
                                Image(systemName: "location.fill.viewfinder")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .frame(width: 70, height: 70)
                            .onAppear {
                                print("❌ Place image failed: \(error)")
                            }
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray)
                                .frame(width: 70, height: 70)
                        }
                    }
                    Text("📍 Place")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("ID: 10")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Testing real images from your migrated collections")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    MembersView()
} 