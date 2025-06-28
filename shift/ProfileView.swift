import SwiftUI



struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var userSession = FirebaseUserSession.shared
    @StateObject private var membersService = FirebaseMembersService()
    @State private var userMember: FirebaseMember?
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header Section
                    VStack(spacing: 15) {
                        // Profile Image
                        if let profileImage = userSession.currentUser?.profilePhoto, !profileImage.isEmpty {
                            AsyncImage(url: URL(string: profileImage)) { image in
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
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray)
                                .frame(width: 120, height: 120)
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
        
        // Fetch the user's member profile
        membersService.fetchMembers()
        
        // Find the member profile for the current user
        // This assumes you have a way to link users to members (by user ID or email)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // For now, try to find by first name match
            // In a real app, you'd want a proper user ID relationship
            userMember = membersService.members.first { member in
                member.firstName.lowercased() == currentUser.firstName?.lowercased()
            }
            isLoading = false
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