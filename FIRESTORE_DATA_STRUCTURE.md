# Firestore Data Structure for Shift App

## 🎯 **Complete Data with Image URLs**

After running the upload script, your Firestore will contain complete documents with **all original Adalo data PLUS Firebase image URLs**.

---

## 📊 **Collections Structure**

### **👥 users/{adaloId}**
```javascript
{
  // Original Adalo Data
  id: 5,
  Email: "sterrymacey@utexas.edu",
  Username: "maceysterry",
  "First Name": "macey",
  Gender: "female",
  "Attracted to": "male",
  Age: 26,
  City: {
    name: "Austin",
    coordinates: { latitude: 30.267153, longitude: -97.7430608 }
  },
  "Instagram Handle": "macey_elise",
  
  // Firebase Image URLs (NEW!)
  profileImageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/5_1751051525259.jpeg",
  firebaseImageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/profile_images/5_1751051525259.jpeg",
  
  // Metadata
  adaloId: 5,
  collectionType: "users",
  imageSource: "firebase_storage",
  migratedAt: Timestamp,
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### **🎉 events/{adaloId}**
```javascript
{
  // Original Adalo Data
  id: 98,
  "Venue Name": "Space Cowboy",
  "Event Location": {
    name: "Space Cowboy",
    coordinates: { latitude: 30.2621213, longitude: -97.721464 },
    fullAddress: "1917 E 7th St, Austin, TX 78702, USA"
  },
  
  // Firebase Image URLs (NEW!)
  imageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/event_images/98_1751051444605.png",
  firebaseImageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/event_images/98_1751051444605.png",
  
  // Metadata
  adaloId: 98,
  collectionType: "events",
  imageSource: "firebase_storage",
  migratedAt: Timestamp
}
```

### **📍 places/{adaloId}**
```javascript
{
  // Original Adalo Data
  id: 1,
  "Place Name": "Cosmic Saltillo",
  "Place Locatioon": {
    name: "Cosmic Saltillo",
    coordinates: { latitude: 30.2622875, longitude: -97.7299876 },
    fullAddress: "1300 E 4th St, Austin, TX 78702, USA"
  },
  Users: [259, 309, 341, 503, 725], // User IDs who checked in
  
  // Firebase Image URLs (NEW!)
  imageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/place_images/1_1751051444605.jpg",
  firebaseImageUrl: "https://storage.googleapis.com/shift-12948.firebasestorage.app/place_images/1_1751051444605.jpg",
  
  // Metadata
  adaloId: 1,
  collectionType: "places",
  imageSource: "firebase_storage",
  migratedAt: Timestamp
}
```

---

## 🔍 **Swift App Queries**

### **Get User with Profile Image**
```swift
let userRef = db.collection("users").document("5")
userRef.getDocument { document, error in
    if let doc = document, doc.exists {
        let userData = doc.data()
        let name = userData?["First Name"] as? String
        let profileImageUrl = userData?["profileImageUrl"] as? String
        let email = userData?["Email"] as? String
        
        // Load image from profileImageUrl
    }
}
```

### **Get All Users in Austin with Images**
```swift
db.collection("users")
    .whereField("City.name", isEqualTo: "Austin")
    .whereField("firebaseImageUrl", isNotEqualTo: NSNull())
    .getDocuments { snapshot, error in
        for document in snapshot?.documents ?? [] {
            let userData = document.data()
            let imageUrl = userData["firebaseImageUrl"] as? String
            // Display user with image
        }
    }
```

### **Get Events at Specific Location**
```swift
db.collection("events")
    .whereField("Venue Name", isEqualTo: "Space Cowboy")
    .getDocuments { snapshot, error in
        for document in snapshot?.documents ?? [] {
            let eventData = document.data()
            let eventImageUrl = eventData["imageUrl"] as? String
            let venueName = eventData["Venue Name"] as? String
        }
    }
```

### **Get Places with Check-ins**
```swift
db.collection("places")
    .whereField("Users", arrayContains: currentUserAdaloId)
    .getDocuments { snapshot, error in
        for document in snapshot?.documents ?? [] {
            let placeData = document.data()
            let placeImageUrl = placeData["imageUrl"] as? String
            let placeName = placeData["Place Name"] as? String
        }
    }
```

---

## 🎯 **Key Benefits**

✅ **Document ID = Adalo ID**: Easy to reference and match  
✅ **Complete Data**: All original fields preserved  
✅ **Image URLs**: Direct Firebase Storage links  
✅ **Consistent Structure**: Same field names as your current code  
✅ **Queryable**: Can search by location, name, check-ins, etc.  
✅ **Timestamps**: Proper Firestore timestamp handling  

---

## 📱 **For Your Swift App**

Your existing code should work with minimal changes:
1. **Document IDs**: Use the original Adalo IDs you're already using
2. **Image URLs**: Replace Adalo image URLs with `firebaseImageUrl` field
3. **Data Fields**: All the same field names (`"First Name"`, `"Venue Name"`, etc.)

The script creates **complete, self-contained documents** that your app can query efficiently! 🚀 