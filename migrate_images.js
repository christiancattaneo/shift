const admin = require('firebase-admin');

// Initialize Firebase Admin using default project credentials
admin.initializeApp({
  projectId: 'shift-12948',
  storageBucket: 'shift-12948.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

async function migrateProfileImages() {
  console.log('🔗 Starting profile image migration...');
  
  try {
    // Step 1: Get all profile images from Firebase Storage
    const [files] = await bucket.getFiles({
      prefix: 'profile_images/'
    });
    
    console.log(`📁 Found ${files.length} profile images in storage`);
    
    // Step 2: Extract Adalo IDs from filenames
    const adaloIdToImages = {};
    
    files.forEach(file => {
      const filename = file.name.split('/').pop();
      const adaloId = filename.split('_')[0];
      
      if (adaloId && !isNaN(parseInt(adaloId))) {
        if (!adaloIdToImages[adaloId]) {
          adaloIdToImages[adaloId] = [];
        }
        adaloIdToImages[adaloId].push(file);
      }
    });
    
    console.log(`🔍 Extracted ${Object.keys(adaloIdToImages).length} unique Adalo IDs`);
    console.log(`🔍 Sample IDs: ${Object.keys(adaloIdToImages).slice(0, 10).join(', ')}`);
    
    // Step 3: Get all users from Firestore
    const usersSnapshot = await db.collection('users').get();
    console.log(`👥 Found ${usersSnapshot.size} users in Firestore`);
    
    let updatedCount = 0;
    
    // Step 4: Update users with image URLs
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const firstName = data.firstName || 'Unknown';
      
      // Find Adalo ID using multiple strategies
      let adaloId = null;
      
      // Strategy 1: Direct adaloId field
      if (data.adaloId) {
        adaloId = String(data.adaloId);
        console.log(`Found adaloId for ${firstName}: ${adaloId}`);
      }
      // Strategy 2: originalId field  
      else if (data.originalId) {
        adaloId = String(data.originalId);
        console.log(`Found originalId for ${firstName}: ${adaloId}`);
      }
      // Strategy 3: Look for any numeric field that has images
      else {
        for (const [key, value] of Object.entries(data)) {
          if (typeof value === 'number' && value > 0 && value < 10000) {
            if (adaloIdToImages[String(value)]) {
              adaloId = String(value);
              console.log(`Inferred adaloId for ${firstName} from ${key}: ${adaloId}`);
              break;
            }
          }
        }
      }
      
      if (adaloId && adaloIdToImages[adaloId]) {
        const imageFile = adaloIdToImages[adaloId][0]; // Get first image
        
        // Get public download URL
        await imageFile.makePublic();
        const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${imageFile.name}`;
        
        // Update Firestore document
        await doc.ref.update({
          profileImageUrl: publicUrl,
          firebaseImageUrl: publicUrl,
          adaloId: parseInt(adaloId),
          profileImageMappedAt: admin.firestore.Timestamp.now()
        });
        
        console.log(`✅ Updated ${firstName} (ID: ${adaloId}) with image: ${publicUrl}`);
        updatedCount++;
      } else {
        console.log(`⚠️  No image found for ${firstName} (checked adaloId: ${adaloId})`);
      }
    }
    
    console.log(`🎉 Migration complete! Updated ${updatedCount} users with profile images`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
  
  process.exit(0);
}

migrateProfileImages(); 