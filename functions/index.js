const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Main function to map all existing profile images
exports.mapProfileImages = functions.https.onRequest(async (req, res) => {
  console.log('🔗 Starting server-side image mapping...');
  
  try {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();
    
    // Get all profile images from Firebase Storage
    const [files] = await bucket.getFiles({
      prefix: 'profile_images/',
      delimiter: '/'
    });
    
    console.log(`📁 Found ${files.length} profile images in storage`);
    
    // Extract Adalo IDs from filenames
    const adaloIdToImages = {};
    
    files.forEach(file => {
      const filename = file.name.split('/').pop();
      const adaloId = filename.split('_')[0];
      
      if (/^\d+$/.test(adaloId)) {
        if (!adaloIdToImages[adaloId]) {
          adaloIdToImages[adaloId] = [];
        }
        adaloIdToImages[adaloId].push(file);
      }
    });
    
    console.log(`🔍 Extracted ${Object.keys(adaloIdToImages).length} unique Adalo IDs`);
    
    // Get all users from Firestore
    const usersSnapshot = await db.collection('users').get();
    console.log(`👥 Found ${usersSnapshot.size} users in Firestore`);
    
    const batch = db.batch();
    let updateCount = 0;
    
    // Match users to images and prepare batch updates
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
        const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${imageFile.name}`;
        
        batch.update(doc.ref, {
          profileImageUrl: publicUrl,
          firebaseImageUrl: publicUrl,
          adaloId: parseInt(adaloId),
          profileImageMappedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        updateCount++;
        console.log(`✅ Prepared update for ${firstName} with image ${adaloId}`);
      } else {
        console.log(`⚠️ No image mapping found for ${firstName}`);
      }
    }
    
    // Execute batch update
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

// Auto-trigger when new users are created (SCALABLE!)
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    const firstName = userData.firstName || 'Unknown';
    
    console.log(`🆕 New user created: ${firstName}, attempting image mapping...`);
    
    try {
      const storage = admin.storage();
      const bucket = storage.bucket();
      
      // Try to find Adalo ID in the new user data
      let adaloId = null;
      if (userData.adaloId) {
        adaloId = String(userData.adaloId);
      } else if (userData.originalId) {
        adaloId = String(userData.originalId);
      }
      
      if (adaloId) {
        // Look for matching image in storage
        const [files] = await bucket.getFiles({
          prefix: `profile_images/${adaloId}_`
        });
        
        if (files.length > 0) {
          const imageFile = files[0];
          const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${imageFile.name}`;
          
          // Update the user document with image URL
          await snap.ref.update({
            profileImageUrl: publicUrl,
            firebaseImageUrl: publicUrl,
            profileImageMappedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          console.log(`✅ Auto-mapped image for new user ${firstName}`);
        }
      }
    } catch (error) {
      console.error(`❌ Error auto-mapping image for ${firstName}:`, error);
    }
    
    return null;
  });

// Function to handle image uploads and create proper naming
exports.onImageUpload = functions.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const fileName = filePath.split('/').pop();
  
  console.log(`📸 New image uploaded: ${fileName}`);
  
  // If it's a profile image and has proper naming, update the user
  if (filePath.startsWith('profile_images/') && fileName.includes('_')) {
    const adaloId = fileName.split('_')[0];
    
    if (/^\d+$/.test(adaloId)) {
      try {
        const db = admin.firestore();
        const usersSnapshot = await db.collection('users')
          .where('adaloId', '==', parseInt(adaloId))
          .get();
        
        if (!usersSnapshot.empty) {
          const userDoc = usersSnapshot.docs[0];
          const publicUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${filePath}`;
          
          await userDoc.ref.update({
            profileImageUrl: publicUrl,
            firebaseImageUrl: publicUrl,
            profileImageUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
          
          console.log(`✅ Updated profile image for user with adaloId ${adaloId}`);
        }
      } catch (error) {
        console.error(`❌ Error updating profile image:`, error);
      }
    }
  }
  
  return null;
});

// DEBUG: Find specific user by Instagram and check their image mapping
exports.debugUserImage = functions.https.onRequest(async (req, res) => {
  const instagramHandle = req.query.instagram || 'chief.hype';
  
  console.log(`🔍 DEBUG: Looking for user with Instagram: ${instagramHandle}`);
  
  try {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();
    
    // Find user with this Instagram handle
    const usersSnapshot = await db.collection('users')
      .where('instagramHandle', '==', instagramHandle)
      .get();
    
    if (usersSnapshot.empty) {
      // Try searching without @ symbol
      const cleanHandle = instagramHandle.replace('@', '');
      const usersSnapshot2 = await db.collection('users')
        .where('instagramHandle', '==', cleanHandle)
        .get();
      
      if (usersSnapshot2.empty) {
        return res.status(404).json({
          error: `No user found with Instagram handle: ${instagramHandle}`
        });
      }
      
      usersSnapshot = usersSnapshot2;
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    const userId = userDoc.id;
    
    console.log(`✅ Found user: ${userData.firstName} (${userData.instagramHandle})`);
    console.log(`📋 User document ID: ${userId}`);
    console.log(`📋 Full user data:`, JSON.stringify(userData, null, 2));
    
    // Get all profile images to see what's available
    const [files] = await bucket.getFiles({
      prefix: 'profile_images/',
      delimiter: '/'
    });
    
    console.log(`📁 Total profile images in storage: ${files.length}`);
    
    // Find images that might belong to this user
    const userImages = [];
    const allImagesByAdaloId = {};
    
    files.forEach(file => {
      const filename = file.name.split('/').pop();
      const adaloId = filename.split('_')[0];
      
      if (/^\d+$/.test(adaloId)) {
        if (!allImagesByAdaloId[adaloId]) {
          allImagesByAdaloId[adaloId] = [];
        }
        allImagesByAdaloId[adaloId].push(file.name);
        
        // Check if this could be our user's image
        if (userData.adaloId && String(userData.adaloId) === adaloId) {
          userImages.push({
            filename: file.name,
            adaloId: adaloId,
            reason: 'Matches userData.adaloId'
          });
        }
        
        // Check other potential ID fields
        for (const [key, value] of Object.entries(userData)) {
          if (typeof value === 'number' && String(value) === adaloId) {
            userImages.push({
              filename: file.name,
              adaloId: adaloId,
              reason: `Matches userData.${key} = ${value}`
            });
          }
        }
      }
    });
    
    // Current image URLs in user document
    const currentImageUrls = {
      profileImageUrl: userData.profileImageUrl,
      firebaseImageUrl: userData.firebaseImageUrl,
      profilePhoto: userData.profilePhoto
    };
    
    // Extract adaloId from current image URL if possible
    let currentMappedId = null;
    if (userData.profileImageUrl) {
      const match = userData.profileImageUrl.match(/profile_images\/(\d+)_/);
      if (match) {
        currentMappedId = match[1];
      }
    }
    
    const debugInfo = {
      user: {
        documentId: userId,
        firstName: userData.firstName,
        instagramHandle: userData.instagramHandle,
        adaloId: userData.adaloId,
        allNumericFields: Object.entries(userData)
          .filter(([key, value]) => typeof value === 'number')
          .reduce((obj, [key, value]) => ({ ...obj, [key]: value }), {})
      },
      currentImageMapping: {
        profileImageUrl: userData.profileImageUrl,
        firebaseImageUrl: userData.firebaseImageUrl,
        profilePhoto: userData.profilePhoto,
        currentMappedAdaloId: currentMappedId
      },
      potentialCorrectImages: userImages,
      allAdaloIdsWithImages: Object.keys(allImagesByAdaloId).sort((a, b) => parseInt(a) - parseInt(b)),
      totalImagesInStorage: files.length
    };
    
    console.log('🔍 DEBUG RESULTS:', JSON.stringify(debugInfo, null, 2));
    
    res.status(200).json({
      success: true,
      debug: debugInfo,
      recommendation: userImages.length > 0 ? 
        `Found ${userImages.length} potential correct image(s). Current image is mapped to adaloId ${currentMappedId}` :
        'No matching images found - user may need a new image upload'
    });
    
  } catch (error) {
    console.error('❌ Debug error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// COMPREHENSIVE MIGRATION: Fresh pull from Adalo with proper UUIDs
exports.completeMigration = functions.https.onRequest(async (req, res) => {
  console.log('🚀 Starting complete migration from Adalo to Firebase with proper UUIDs...');
  
  try {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();
    
    // Step 1: Get ALL users from Adalo API
    console.log('📡 Step 1: Fetching ALL users from Adalo API...');
    
    const adaloApiKey = process.env.ADALO_API_KEY; // You'll need to set this
    const adaloAppId = process.env.ADALO_APP_ID;   // You'll need to set this
    
    if (!adaloApiKey || !adaloAppId) {
      return res.status(400).json({
        error: 'Missing Adalo API credentials. Set ADALO_API_KEY and ADALO_APP_ID environment variables.'
      });
    }
    
    // Fetch all users from Adalo (paginated)
    const allAdaloUsers = [];
    let offset = 0;
    const limit = 100;
    let hasMore = true;
    
    while (hasMore) {
      const response = await fetch(`https://api.adalo.com/v0/apps/${adaloAppId}/collections/users?offset=${offset}&limit=${limit}`, {
        headers: {
          'Authorization': `Bearer ${adaloApiKey}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (!response.ok) {
        throw new Error(`Adalo API error: ${response.status} ${response.statusText}`);
      }
      
      const data = await response.json();
      allAdaloUsers.push(...data.records);
      
      hasMore = data.records.length === limit;
      offset += limit;
      
      console.log(`📋 Fetched ${allAdaloUsers.length} users so far...`);
    }
    
    console.log(`✅ Fetched total ${allAdaloUsers.length} users from Adalo`);
    
    // Step 2: Download and re-upload all profile images with proper naming
    console.log('📸 Step 2: Migrating profile images with proper UUIDs...');
    
    const migrationResults = {
      totalUsers: allAdaloUsers.length,
      successfulMigrations: 0,
      skippedUsers: 0,
      errors: []
    };
    
    for (const adaloUser of allAdaloUsers) {
      try {
        // Generate proper Firebase UID for this user
        const firebaseUID = `adalo_${adaloUser.id}_${Date.now()}`;
        
        // Prepare clean user data
        const cleanUserData = {
          // Firebase fields
          uid: firebaseUID,
          migratedFrom: 'adalo',
          migrationDate: admin.firestore.FieldValue.serverTimestamp(),
          
          // Core user data
          firstName: adaloUser['First Name'] || adaloUser.firstName || '',
          lastName: adaloUser['Last Name'] || adaloUser.lastName || '',
          fullName: adaloUser['Full Name'] || adaloUser.fullName || '',
          email: adaloUser.Email || adaloUser.email || '',
          age: adaloUser.Age || adaloUser.age || null,
          gender: adaloUser.Gender || adaloUser.gender || '',
          city: adaloUser.City?.name || adaloUser.city || '',
          
          // Dating app specific
          attractedTo: adaloUser['Attracted to'] || adaloUser.attractedTo || '',
          howToApproachMe: adaloUser['How To Approach Me'] || adaloUser.howToApproachMe || '',
          instagramHandle: adaloUser['Instagram Handle'] || adaloUser.instagramHandle || '',
          
          // Legacy reference
          originalAdaloId: adaloUser.id,
          originalAdaloData: adaloUser, // Keep full original data for reference
          
          // Timestamps
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        // Step 3: Handle profile image migration
        let profileImageUrl = null;
        
        if (adaloUser['Profile Photo'] && adaloUser['Profile Photo'].url) {
          const originalImageUrl = adaloUser['Profile Photo'].url;
          
          try {
            // Download image from Adalo
            const imageResponse = await fetch(originalImageUrl);
            if (imageResponse.ok) {
              const imageBuffer = await imageResponse.buffer();
              
              // Create proper filename: {firebaseUID}.jpg
              const newImagePath = `profile_images_v2/${firebaseUID}.jpg`;
              const file = bucket.file(newImagePath);
              
              // Upload to Firebase Storage with proper metadata
              await file.save(imageBuffer, {
                metadata: {
                  contentType: 'image/jpeg',
                  metadata: {
                    migratedFrom: 'adalo',
                    originalAdaloId: String(adaloUser.id),
                    originalUrl: originalImageUrl,
                    firebaseUID: firebaseUID
                  }
                }
              });
              
              // Generate public URL
              profileImageUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${newImagePath}`;
              
              console.log(`📸 Migrated image for ${cleanUserData.firstName} (${firebaseUID})`);
            }
          } catch (imageError) {
            console.error(`❌ Failed to migrate image for user ${adaloUser.id}:`, imageError.message);
            migrationResults.errors.push({
              userId: adaloUser.id,
              type: 'image_migration',
              error: imageError.message
            });
          }
        }
        
        // Add image URL to user data
        if (profileImageUrl) {
          cleanUserData.profileImageUrl = profileImageUrl;
          cleanUserData.firebaseImageUrl = profileImageUrl;
          cleanUserData.hasProfileImage = true;
        } else {
          cleanUserData.hasProfileImage = false;
        }
        
        // Step 4: Create user document in new collection
        await db.collection('users_v2').doc(firebaseUID).set(cleanUserData);
        
        migrationResults.successfulMigrations++;
        
        if (migrationResults.successfulMigrations % 10 === 0) {
          console.log(`✅ Migrated ${migrationResults.successfulMigrations}/${allAdaloUsers.length} users`);
        }
        
      } catch (userError) {
        console.error(`❌ Failed to migrate user ${adaloUser.id}:`, userError.message);
        migrationResults.errors.push({
          userId: adaloUser.id,
          type: 'user_migration',
          error: userError.message
        });
        migrationResults.skippedUsers++;
      }
    }
    
    console.log('🎉 Migration completed!', migrationResults);
    
    res.status(200).json({
      success: true,
      message: 'Complete migration finished',
      results: migrationResults,
      nextSteps: [
        '1. Review migrated data in users_v2 collection',
        '2. Update app to use users_v2 collection',
        '3. Test thoroughly with new UUID system',
        '4. When confident, rename users_v2 to users (backup old first)'
      ]
    });
    
  } catch (error) {
    console.error('❌ Migration error:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Helper function to fix current user specifically (immediate fix)
exports.fixUserImage = functions.https.onRequest(async (req, res) => {
  const instagramHandle = req.query.instagram || 'chief.hype';
  
  try {
    const db = admin.firestore();
    const storage = admin.storage();
    const bucket = storage.bucket();
    
    // Find user
    const usersSnapshot = await db.collection('users')
      .where('instagramHandle', '==', instagramHandle)
      .get();
    
    if (usersSnapshot.empty) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userDoc = usersSnapshot.docs[0];
    const userData = userDoc.data();
    
    // Get all images for this user's adaloId
    const [files] = await bucket.getFiles({
      prefix: `profile_images/${userData.adaloId}_`
    });
    
    if (files.length === 0) {
      return res.status(404).json({ error: 'No images found for this user' });
    }
    
    // Sort by timestamp (newest first)
    const sortedFiles = files.sort((a, b) => {
      const timestampA = a.name.split('_')[1]?.split('.')[0];
      const timestampB = b.name.split('_')[1]?.split('.')[0];
      return parseInt(timestampB) - parseInt(timestampA);
    });
    
    // Use the newest image
    const newestImage = sortedFiles[0];
    const newImageUrl = `https://storage.googleapis.com/shift-12948.firebasestorage.app/${newestImage.name}`;
    
    // Update user with newest image
    await userDoc.ref.update({
      profileImageUrl: newImageUrl,
      firebaseImageUrl: newImageUrl,
      imageFixedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.status(200).json({
      success: true,
      message: `Fixed image for ${userData.firstName}`,
      oldImage: userData.profileImageUrl,
      newImage: newImageUrl,
      availableImages: files.map(f => f.name)
    });
    
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
}); 