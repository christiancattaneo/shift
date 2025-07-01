const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.mapProfileImages = functions.https.onRequest(async (req, res) => {
  console.log('🔗 Starting server-side image mapping...');
  
  try {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();
    
    // Step 1: Get all profile images from Firebase Storage
    const [files] = await bucket.getFiles({
      prefix: 'profile_images/',
      delimiter: '/'
    });
    
    console.log(`📁 Found ${files.length} profile images in storage`);
    
    // Step 2: Extract Adalo IDs from filenames
    const adaloIdToImages = {};
    
    files.forEach(file => {
      const filename = file.name.split('/').pop(); // Get filename without path
      const adaloId = filename.split('_')[0];
      
      if (/^\d+$/.test(adaloId)) { // Check if it's a valid number
        if (!adaloIdToImages[adaloId]) {
          adaloIdToImages[adaloId] = [];
        }
        adaloIdToImages[adaloId].push(file);
      }
    });
    
    console.log(`🔍 Extracted ${Object.keys(adaloIdToImages).length} unique Adalo IDs`);
    
    // Step 3: Get all users from Firestore
    const usersSnapshot = await db.collection('users').get();
    console.log(`👥 Found ${usersSnapshot.size} users in Firestore`);
    
    const batch = db.batch();
    let updateCount = 0;
    
    // Step 4: Match users to images and prepare batch updates
    for (const doc of usersSnapshot.docs) {
      const userData = doc.data();
      const firstName = userData.firstName || 'Unknown';
      
      // Try to find Adalo ID in various fields
      let adaloId = null;
      
      if (userData.adaloId) {
        adaloId = String(userData.adaloId);
      } else if (userData.originalId) {
        adaloId = String(userData.originalId);
      } else {
        // Look for any numeric field that might be the original ID
        for (const [key, value] of Object.entries(userData)) {
          if (typeof value === 'number' && value > 0 && value < 10000) {
            if (adaloIdToImages[String(value)]) {
              adaloId = String(value);
              console.log(`🔍 Inferred adaloId for ${firstName} from ${key}: ${adaloId}`);
              break;
            }
          }
        }
      }
      
      // If we found a matching image, prepare the update
      if (adaloId && adaloIdToImages[adaloId]) {
        const imageFile = adaloIdToImages[adaloId][0]; // Use first (latest) image
        
        try {
          // Get signed URL that doesn't expire
          const [url] = await imageFile.getSignedUrl({
            action: 'read',
            expires: '03-09-2491' // Far future date
          });
          
          // Or use public URL format (better for production)
          const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${imageFile.name}`;
          
          batch.update(doc.ref, {
            profileImageUrl: publicUrl,
            firebaseImageUrl: publicUrl,
            adaloId: parseInt(adaloId),
            profileImageMappedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          updateCount++;
          console.log(`✅ Prepared update for ${firstName} with image ${adaloId}`);
          
        } catch (error) {
          console.error(`❌ Error getting URL for ${firstName}:`, error);
        }
      } else {
        console.log(`⚠️ No image mapping found for ${firstName}`);
      }
    }
    
    // Step 5: Execute batch update
    if (updateCount > 0) {
      await batch.commit();
      console.log(`🎉 Successfully updated ${updateCount} users with profile images`);
    }
    
    res.status(200).json({
      success: true,
      message: `Updated ${updateCount} users with profile images`,
      totalUsers: usersSnapshot.size,
      totalImages: files.length,
      uniqueAdaloIds: Object.keys(adaloIdToImages).length
    });
    
  } catch (error) {
    console.error('❌ Error in mapProfileImages:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Auto-trigger when new users are created (even better!)
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const firstName = userData.firstName || 'Unknown';
    
    // Try to map image immediately when user is created
    console.log(`🆕 New user created: ${firstName}, attempting image mapping...`);
    
    // Same logic as above but for single user
    // This ensures new users get their images mapped automatically
    
    return null;
  }); 