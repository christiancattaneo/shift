import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userSession = FirebaseUserSession.shared
    @ObservedObject private var membersService = FirebaseMembersService.shared
    @State private var userMember: FirebaseMember?
    @State private var isLoading = true
    @State private var currentUserImageUrl: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header Section
                    VStack(spacing: 15) {
                        // Profile Image - Now using migrated data
                        if let imageUrl = currentUserImageUrl, !imageUrl.isEmpty {
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .onAppear {
                                print("🖼️ ProfileView: Loading image URL: \(imageUrl)")
                            }
                        } else if let legacyPhoto = userSession.currentUser?.profilePhoto, !legacyPhoto.isEmpty {
                            // Fallback to legacy profile photo
                            AsyncImage(url: URL(string: legacyPhoto)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .onAppear {
                                print("🖼️ ProfileView: Using legacy photo: \(legacyPhoto)")
                            }
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
                                .onAppear {
                                    print("🖼️ ProfileView: No image URL available - currentUserImageUrl: \(currentUserImageUrl ?? "nil"), legacyPhoto: \(userSession.currentUser?.profilePhoto ?? "nil")")
                                }
                        }
                        
                        // User Name
                        Text(userSession.currentUser?.firstName ?? "Unknown User")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        // Age (if available from member profile)
                        if let userMember = userMember, let age = userMember.age {
                            Text("\(age)")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Profile Information Section
                    if isLoading {
                        ProgressView("Loading profile...")
                            .padding()
                    } else if let userMember = userMember {
                        VStack(spacing: 15) {
                            // City
                            if let city = userMember.city {
                                InfoRow(icon: "mappin.and.ellipse", label: "City", value: city)
                            }
                            
                            // Approach Tip
                            if let approachTip = userMember.approachTip {
                                InfoRow(icon: "lightbulb.fill", label: "Tip to Approach Me", value: approachTip)
                            }
                            
                            // Attracted To
                            if let attractedTo = userMember.attractedTo {
                                InfoRow(icon: "figure.dress.line.vertical.figure", label: "Attracted to", value: attractedTo)
                            }
                            
                            // Instagram Handle
                            if let handle = userMember.instagramHandle, !handle.isEmpty {
                                InfoRow(icon: "camera.fill", label: "Instagram", value: handle)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 15) {
                            Text("Complete your profile")
                                .font(.title2)
                                .fontWeight(.medium)
                            Text("Add more details to help others connect with you!")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                    
                    Spacer(minLength: 50)
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        // Edit Profile Button
                        NavigationLink(destination: EditProfileView(userMember: userMember)) {
                            HStack {
                                Image(systemName: "pencil")
                                Text(userMember == nil ? "Complete Profile" : "Edit Profile")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        
                        // Sign Out Button
                        Button(action: {
                            userSession.signOut()
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                            .font(.headline)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadUserMemberProfile()
        }
    }
    
    private func loadUserMemberProfile() {
        guard let currentUser = userSession.currentUser else {
            isLoading = false
            return
        }
        
        print("🔍 ProfileView: Loading profile for user: \(currentUser.firstName ?? "Unknown")")
        
        // First, load the current user's updated document to get migrated image URL
        Task {
            await loadCurrentUserImageUrl()
        }
        
        // Fetch the user's member profile
        membersService.fetchMembers()
        
        // Find the member profile for the current user
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Try to find by Firebase document ID first (most reliable)
            if let userId = currentUser.id {
                userMember = membersService.members.first { member in
                    member.id == userId || member.userId == userId
                }
            }
            
            // Fallback: find by first name match
            if userMember == nil {
                userMember = membersService.members.first { member in
                    member.firstName.lowercased() == currentUser.firstName?.lowercased()
                }
            }
            
            print("🔍 ProfileView: Found user member: \(userMember?.firstName ?? "nil")")
            if let userMember = userMember {
                print("🔍 ProfileView: Member image URLs - profileImageUrl: \(userMember.profileImageUrl ?? "nil"), firebaseImageUrl: \(userMember.firebaseImageUrl ?? "nil")")
                
                // Use the member's image URL if current user doesn't have one
                if currentUserImageUrl == nil {
                    currentUserImageUrl = userMember.profileImageUrl ?? userMember.firebaseImageUrl
                    print("🔍 ProfileView: Using member image URL: \(currentUserImageUrl ?? "nil")")
                }
            }
            
            isLoading = false
        }
    }
    
    private func loadCurrentUserImageUrl() async {
        guard let currentUser = userSession.currentUser,
              let userId = currentUser.id else { return }
        
        print("🔍 ProfileView: Loading current user document for migrated image URL")
        
        // Load the user's document directly to get migrated fields
        do {
            let db = Firestore.firestore()
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists {
                let data = document.data()
                let profileImageUrl = data?["profileImageUrl"] as? String
                let firebaseImageUrl = data?["firebaseImageUrl"] as? String
                let profilePhoto = data?["profilePhoto"] as? String
                
                print("🔍 ProfileView: Document data - profileImageUrl: \(profileImageUrl ?? "nil"), firebaseImageUrl: \(firebaseImageUrl ?? "nil"), profilePhoto: \(profilePhoto ?? "nil")")
                
                await MainActor.run {
                    // Use the migrated URL first, fallback to legacy
                    currentUserImageUrl = profileImageUrl ?? firebaseImageUrl ?? profilePhoto
                    print("🔍 ProfileView: Set currentUserImageUrl: \(currentUserImageUrl ?? "nil")")
                }
            } else {
                print("🔍 ProfileView: User document does not exist")
            }
        } catch {
            print("🔍 ProfileView: Error loading user document: \(error)")
        }
    }
}

// Info Row Component
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ProfileView()
} 