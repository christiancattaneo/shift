const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

// Initialize Firebase Admin SDK using application default credentials
// This works with Firebase CLI authentication
admin.initializeApp({
  projectId: 'shift-12948'
});

const auth = admin.auth();
const db = admin.firestore();

async function migrateUsersToFirebase() {
  const results = [];
  const usersFile = path.join(__dirname, 'data/Users.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(usersFile)
      .pipe(csv())
      .on('data', (data) => {
        results.push(data);
      })
      .on('end', async () => {
        console.log(`🔄 Processing ${results.length} users for migration...`);
        
        let successCount = 0;
        let errorCount = 0;
        
        for (const userData of results) {
          try {
            // Skip users without email
            if (!userData.Email || userData.Email.trim() === '') {
              console.log(`⚠️  Skipping user without email`);
              continue;
            }
            
            const email = userData.Email.trim().toLowerCase();
            
            // Create Firebase Auth user
            let firebaseUser;
            try {
              firebaseUser = await auth.createUser({
                email: email,
                emailVerified: true, // Since they're migrated users
                displayName: userData['First Name'] || userData.Username || 'User',
                // Note: We can't migrate passwords directly, users will need to reset
                disabled: false
              });
              console.log(`✅ Created Firebase Auth user: ${email}`);
            } catch (authError) {
              if (authError.code === 'auth/email-already-exists') {
                // User already exists, get the existing user
                firebaseUser = await auth.getUserByEmail(email);
                console.log(`📝 User already exists: ${email}`);
              } else {
                throw authError;
              }
            }
            
            // Create Firestore profile document
            const profileData = {
              email: email,
              firstName: userData['First Name'] || '',
              fullName: userData['Full Name'] || '',
              username: userData.Username || '',
              profilePhoto: userData.Photo ? extractImageUrl(userData.Photo) : '',
              gender: userData.Gender || '',
              attractedTo: userData['Attracted to'] || '',
              age: userData.Age ? parseInt(userData.Age) : null,
              city: userData.City || '',
              howToApproachMe: userData['How to Approach Me'] || '',
              isEventCreator: userData['Is Event Creator'] === 'TRUE',
              isEventAttendee: userData['Is Event Attendee'] === 'TRUE',
              instagramHandle: userData['Instagram Handle'] || '',
              subscribed: userData.Subscribed === 'TRUE',
              // Migration tracking
              migratedFromAdalo: true,
              migrationDate: admin.firestore.FieldValue.serverTimestamp(),
              passwordResetRequired: true, // Flag to prompt password reset
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };
            
            await db.collection('users').doc(firebaseUser.uid).set(profileData);
            console.log(`📄 Created Firestore profile for: ${email}`);
            
            successCount++;
            
          } catch (error) {
            console.error(`❌ Error migrating user ${userData.Email}:`, error.message);
            errorCount++;
          }
        }
        
        console.log(`\n🎉 Migration Complete!`);
        console.log(`✅ Successfully migrated: ${successCount} users`);
        console.log(`❌ Errors: ${errorCount} users`);
        console.log(`\n📧 Users will need to use "Forgot Password" on first login`);
        
        resolve();
      })
      .on('error', reject);
  });
}

// Helper function to extract image URL from Adalo's complex image object
function extractImageUrl(photoData) {
  if (!photoData) return '';
  
  try {
    // If it's already a simple URL
    if (typeof photoData === 'string' && photoData.startsWith('http')) {
      return photoData;
    }
    
    // If it's Adalo's complex object format
    if (photoData.includes('"url"')) {
      const parsed = JSON.parse(photoData);
      return parsed.url || '';
    }
    
    return '';
  } catch (error) {
    console.log(`⚠️  Could not parse photo data: ${photoData}`);
    return '';
  }
}

// Run the migration
migrateUsersToFirebase()
  .then(() => {
    console.log('Migration completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  }); 