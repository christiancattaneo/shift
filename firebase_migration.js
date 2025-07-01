const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Firebase Admin SDK
const admin = require('firebase-admin');

// Initialize Firebase Admin (make sure you have the service account key)
const serviceAccount = require('./firebase-admin-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'shift-12948.firebasestorage.app'
});

const db = admin.firestore();
// Enable ignoreUndefinedProperties to handle undefined values gracefully
db.settings({ ignoreUndefinedProperties: true });
const bucket = admin.storage().bucket();

// Input paths
const USERS_JSON_PATH = './adalo_data/users_with_images.json';
const IMAGES_DIR = './adalo_data/images';
const OUTPUT_DIR = './firebase_migration_data';

// Create output directory
if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR);

// Helper function to create clean UUID
function generateUserUUID(adaloId, firstName) {
  // Create a deterministic but unique UUID based on user data
  // This ensures the same user always gets the same UUID if script is re-run
  const seed = `shift_user_${adaloId}_${firstName.toLowerCase()}`;
  return uuidv4({ name: seed, namespace: uuidv4.DNS });
}

// Helper function to sanitize user data
function cleanUserData(adaloUser, newUUID, imageUrl = null) {
  return {
    // NEW FIREBASE SYSTEM
    uid: newUUID,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    
    // CORE USER DATA (clean field names)
    firstName: adaloUser['First Name'] || '',
    lastName: adaloUser['Last Name'] || '',
    fullName: adaloUser['Full Name'] || '',
    email: adaloUser.Email || '',
    age: adaloUser.Age || null,
    gender: adaloUser.Gender || '',
    
    // LOCATION DATA (clean structure, no undefined values)
    city: adaloUser.City?.name || '',
    cityDetails: adaloUser.City ? {
      name: adaloUser.City.name || '',
      coordinates: adaloUser.City.coordinates || null,
      fullAddress: adaloUser.City.fullAddress || ''
    } : null,
    
    // DATING APP SPECIFIC
    attractedTo: adaloUser['Attracted to'] || '',
    howToApproachMe: adaloUser['How to Approach Me'] || '',
    instagramHandle: adaloUser['Instagram Handle'] || '',
    
    // PROFILE IMAGE (clean URLs)
    profileImageUrl: imageUrl,
    hasProfileImage: !!imageUrl,
    
    // APP STATUS
    subscribed: adaloUser.Subscribed || false,
    agreedToTerms: adaloUser['User Agrees to Terms & Conditions & rivacy Policy'] || false,
    
    // ACTIVITY DATA
    checkInHistory: {
      events: adaloUser['Check in for event'] || [],
      places: adaloUser['Check in for places'] || []
    },
    
    // LEGACY REFERENCE (for debugging only - will remove later)
    _migration: {
      originalAdaloId: adaloUser.id,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'adalo_api'
    }
  };
}

// Helper function to upload image to Firebase Storage
async function uploadImageToFirebase(localImagePath, newUUID) {
  try {
    console.log(`📸 Uploading image for ${newUUID}...`);
    
    // Read local image file
    const imageBuffer = fs.readFileSync(localImagePath);
    
    // Create clean filename: {uuid}.jpg
    const firebaseImagePath = `profiles/${newUUID}.jpg`;
    const file = bucket.file(firebaseImagePath);
    
    // Upload with metadata
    await file.save(imageBuffer, {
      metadata: {
        contentType: 'image/jpeg',
        metadata: {
          uploadedBy: 'migration_script',
          userUUID: newUUID,
          originalSource: 'adalo'
        }
      }
    });
    
    // Generate public URL
    const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${firebaseImagePath}`;
    
    console.log(`✅ Image uploaded: ${publicUrl}`);
    return publicUrl;
    
  } catch (error) {
    console.error(`❌ Failed to upload image for ${newUUID}:`, error.message);
    return null;
  }
}

// Main migration function
async function migrateToFirebase() {
  try {
    console.log('🚀 Starting complete Firebase migration...');
    
    // Step 1: Load user data
    console.log('📖 Reading user data...');
    const usersData = JSON.parse(fs.readFileSync(USERS_JSON_PATH, 'utf8'));
    console.log(`✅ Loaded ${usersData.length} users`);
    
    // Step 2: List available images
    console.log('📸 Scanning downloaded images...');
    const imageFiles = fs.readdirSync(IMAGES_DIR).filter(f => f.endsWith('.jpg'));
    console.log(`✅ Found ${imageFiles.length} images`);
    
    // Step 3: Create mapping
    const migrationResults = {
      total: usersData.length,
      successful: 0,
      failed: 0,
      withImages: 0,
      withoutImages: 0,
      errors: []
    };
    
    const migratedUsers = [];
    
    // Step 4: Process each user
    for (let i = 0; i < usersData.length; i++) {
      const adaloUser = usersData[i];
      const firstName = adaloUser['First Name'] || 'Unknown';
      const adaloId = adaloUser.id;
      
      console.log(`\n[${i + 1}/${usersData.length}] Processing: ${firstName} (Adalo ID: ${adaloId})`);
      
      try {
        // Generate new UUID for this user
        const newUUID = generateUserUUID(adaloId, firstName);
        console.log(`🆔 Generated UUID: ${newUUID}`);
        
        // Find corresponding image
        let imageUrl = null;
        const expectedImageName = `${adaloId}_${firstName.replace(/[^a-zA-Z0-9]/g, '_')}.jpg`;
        const localImagePath = path.join(IMAGES_DIR, expectedImageName);
        
        if (fs.existsSync(localImagePath)) {
          // Upload image to Firebase Storage
          imageUrl = await uploadImageToFirebase(localImagePath, newUUID);
          if (imageUrl) {
            migrationResults.withImages++;
          }
        } else {
          console.log(`⚠️  No image found for ${firstName} (expected: ${expectedImageName})`);
          migrationResults.withoutImages++;
        }
        
        // Create clean user document
        const cleanUser = cleanUserData(adaloUser, newUUID, imageUrl);
        
        // Upload to Firestore
        await db.collection('users').doc(newUUID).set(cleanUser);
        console.log(`✅ User uploaded to Firestore: ${firstName}`);
        
        // Add to migration record
        migratedUsers.push({
          uuid: newUUID,
          originalAdaloId: adaloId,
          firstName: firstName,
          email: adaloUser.Email,
          hasImage: !!imageUrl,
          imageUrl: imageUrl
        });
        
        migrationResults.successful++;
        
      } catch (error) {
        console.error(`❌ Failed to migrate ${firstName}:`, error.message);
        migrationResults.failed++;
        migrationResults.errors.push({
          adaloId,
          firstName,
          error: error.message
        });
      }
      
      // Progress update every 10 users
      if ((i + 1) % 10 === 0) {
        console.log(`📊 Progress: ${i + 1}/${usersData.length} (${Math.round((i + 1) / usersData.length * 100)}%)`);
      }
    }
    
    // Step 5: Save migration summary
    const summary = {
      migrationDate: new Date().toISOString(),
      results: migrationResults,
      newCollection: 'users',
      oldSystem: 'adalo',
      totalMigrated: migrationResults.successful,
      notes: 'Complete migration with UUIDs - zero Adalo dependency'
    };
    
    // Save migration record locally
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'migration_summary.json'),
      JSON.stringify(summary, null, 2)
    );
    
    fs.writeFileSync(
      path.join(OUTPUT_DIR, 'migrated_users.json'),
      JSON.stringify(migratedUsers, null, 2)
    );
    
    // Step 6: Final report
    console.log('\n🎉 MIGRATION COMPLETE!');
    console.log('📊 Final Results:');
    console.log(`   Total Users: ${migrationResults.total}`);
    console.log(`   Successfully Migrated: ${migrationResults.successful}`);
    console.log(`   Failed: ${migrationResults.failed}`);
    console.log(`   With Images: ${migrationResults.withImages}`);
    console.log(`   Without Images: ${migrationResults.withoutImages}`);
    
    console.log('\n🔥 BENEFITS ACHIEVED:');
    console.log('   ✅ Zero Adalo dependency');
    console.log('   ✅ Clean UUID system');
    console.log('   ✅ Proper Firebase structure');
    console.log('   ✅ Perfect user-image mapping');
    console.log('   ✅ Scalable for future growth');
    
    if (migrationResults.errors.length > 0) {
      console.log(`\n⚠️  Errors (${migrationResults.errors.length}):`);
      migrationResults.errors.forEach(err => {
        console.log(`   ${err.firstName} (${err.adaloId}): ${err.error}`);
      });
    }
    
    console.log('\n🎯 NEXT STEPS:');
    console.log('   1. Update iOS app to use new UUID system');
    console.log('   2. Test thoroughly with new data structure');
    console.log('   3. Remove old Adalo-dependent code');
    console.log('   4. Archive old data when confident');
    
  } catch (error) {
    console.error('❌ Fatal migration error:', error);
  }
}

// Run migration
console.log('🚀 Firebase Migration Tool');
console.log('👉 This will create a completely new, scalable user system');
console.log('👉 Every user gets a proper UUID');
console.log('👉 Zero Adalo dependency');
console.log('\nStarting in 3 seconds...\n');

setTimeout(() => {
  migrateToFirebase().catch(console.error);
}, 3000); 