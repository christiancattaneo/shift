import SwiftUI

struct NewMessageRecipientView: View {
    let members: [FirebaseMember]
    let onSelection: (FirebaseMember) -> Void
    
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    
    var filteredMembers: [FirebaseMember] {
        if searchText.isEmpty {
            return members
        } else {
            return members.filter { member in
                member.firstName.localizedCaseInsensitiveContains(searchText) ||
                (member.city?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (member.instagramHandle?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search people", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Members List
                if filteredMembers.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No people found")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Try adjusting your search")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredMembers, id: \.uniqueID) { member in
                            Button(action: {
                                onSelection(member)
                                dismiss()
                            }) {
                                MemberRow(member: member)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
                        }
                    }
                    .listStyle(PlainListStyle())
                    
                    // Data source indicator
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Real members from Firebase • \(filteredMembers.count) people")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
            )
        }
    }
}

struct MemberRow: View {
    let member: FirebaseMember
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile Image
            AsyncImage(url: member.profileImageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                let _ = print("🖼️ MESSAGES ASYNC: '\(member.firstName)' - Loading placeholder in NewMessageRecipientView, URL: \(member.profileImageURL?.absoluteString ?? "nil")")
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.firstName)
                        .font(.headline)
                    
                    if let age = member.age {
                        Text("\(age)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let city = member.city, !city.isEmpty {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(city)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let attractedTo = member.attractedTo, !attractedTo.isEmpty {
                    Text("Attracted to: \(attractedTo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Approach Tip - using exact same pattern as ProfileView
                if let approachTip = member.approachTip, !approachTip.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(approachTip)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                if let instagram = member.instagramHandle, !instagram.isEmpty {
                    HStack {
                        Image(systemName: "camera")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text("@\(instagram)")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NewMessageRecipientView(
        members: [
            FirebaseMember(
                firstName: "Caroline",
                age: 25,
                city: "Austin",
                attractedTo: "male",
                instagramHandle: "caroline_atx"
            ),
            FirebaseMember(
                firstName: "Marin",
                age: 24,
                city: "Austin",
                attractedTo: "female",
                instagramHandle: "marin_austin"
            )
        ]
    ) { _ in }
} 