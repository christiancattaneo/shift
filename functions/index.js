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
              
              // Generate public URL with proper Firebase Storage format
              profileImageUrl = `https://firebasestorage.googleapis.com/v0/b/shift-12948.firebasestorage.app/o/${encodeURIComponent(newImagePath)}?alt=media`;
              
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

// MARK: - Event Ranking and Popularity System

// ENHANCED: Universal popularity update for both events and places
exports.updatePopularityScores = functions.pubsub.schedule('every 30 minutes').onRun(async (context) => {
  console.log('🔥 Starting popularity update for events and places...');
  
  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const oneDayAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (24 * 60 * 60 * 1000));
    const oneWeekAgo = admin.firestore.Timestamp.fromMillis(now.toMillis() - (7 * 24 * 60 * 60 * 1000));
    
    // Get all active check-ins from the last 24 hours
    const recentCheckInsSnapshot = await db.collection('checkIns')
      .where('isActive', '==', true)
      .where('checkedInAt', '>=', oneDayAgo)
      .get();
    
    // Get all check-ins from the last week
    const weeklyCheckInsSnapshot = await db.collection('checkIns')
      .where('isActive', '==', true)
      .where('checkedInAt', '>=', oneWeekAgo)
      .get();
    
    // Get total check-ins for all time
    const totalCheckInsSnapshot = await db.collection('checkIns')
      .get();
    
    console.log(`📊 Found ${recentCheckInsSnapshot.size} check-ins in last 24h`);
    console.log(`📊 Found ${weeklyCheckInsSnapshot.size} check-ins in last week`);
    console.log(`📊 Found ${totalCheckInsSnapshot.size} total check-ins`);
    
    // Calculate popularity scores by item (event or place)
    const itemPopularity = {};
    
    // Count recent check-ins (last 24 hours)
    recentCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const itemId = data.eventId; // Note: eventId field is used for both events and places
      if (!itemPopularity[itemId]) {
        itemPopularity[itemId] = { recent: 0, weekly: 0, total: 0 };
      }
      itemPopularity[itemId].recent += 1;
    });
    
    // Count weekly check-ins (last 7 days)
    weeklyCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const itemId = data.eventId;
      if (!itemPopularity[itemId]) {
        itemPopularity[itemId] = { recent: 0, weekly: 0, total: 0 };
      }
      itemPopularity[itemId].weekly += 1;
    });
    
    // Count total check-ins for all time (using the existing snapshot)
    totalCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const itemId = data.eventId;
      if (!itemPopularity[itemId]) {
        itemPopularity[itemId] = { recent: 0, weekly: 0, total: 0 };
      }
      itemPopularity[itemId].total += 1;
    });
    
    // Calculate composite popularity score
    // Formula: (recent * 5) + (weekly * 2) + (total * 0.5)
    const popularityScores = {};
    for (const [itemId, stats] of Object.entries(itemPopularity)) {
      const score = (stats.recent * 5) + (stats.weekly * 2) + (stats.total * 0.5);
      popularityScores[itemId] = {
        score: score,
        recentCheckIns: stats.recent,
        weeklyCheckIns: stats.weekly,
        totalCheckIns: stats.total,
        lastUpdated: now
      };
    }
    
    console.log(`📈 Calculated popularity for ${Object.keys(popularityScores).length} items`);
    
    // Update both events and places with popularity scores
    const batch = db.batch();
    let eventUpdateCount = 0;
    let placeUpdateCount = 0;
    
    for (const [itemId, popularity] of Object.entries(popularityScores)) {
      // Try events collection first
      const eventRef = db.collection('events').doc(itemId);
      const eventDoc = await eventRef.get();
      
      if (eventDoc.exists) {
        // It's an event
        batch.update(eventRef, {
          popularityScore: popularity.score,
          recentCheckIns: popularity.recentCheckIns,
          weeklyCheckIns: popularity.weeklyCheckIns,
          totalCheckIns: popularity.totalCheckIns,
          popularityUpdatedAt: popularity.lastUpdated
        });
        eventUpdateCount++;
      } else {
        // Try places collection
        const placeRef = db.collection('places').doc(itemId);
        const placeDoc = await placeRef.get();
        
        if (placeDoc.exists) {
          // It's a place
          batch.update(placeRef, {
            popularityScore: popularity.score,
            recentCheckIns: popularity.recentCheckIns,
            weeklyCheckIns: popularity.weeklyCheckIns,
            totalCheckIns: popularity.totalCheckIns,
            popularityUpdatedAt: popularity.lastUpdated
          });
          placeUpdateCount++;
        }
      }
    }
    
    // Reset popularity for events with no recent activity
    const allEventsSnapshot = await db.collection('events').get();
    allEventsSnapshot.docs.forEach(doc => {
      const eventId = doc.id;
      if (!popularityScores[eventId]) {
        batch.update(doc.ref, {
          popularityScore: 0,
          recentCheckIns: 0,
          weeklyCheckIns: 0,
          totalCheckIns: 0,
          popularityUpdatedAt: now
        });
        eventUpdateCount++;
      }
    });
    
    // Reset popularity for places with no recent activity
    const allPlacesSnapshot = await db.collection('places').get();
    allPlacesSnapshot.docs.forEach(doc => {
      const placeId = doc.id;
      if (!popularityScores[placeId]) {
        batch.update(doc.ref, {
          popularityScore: 0,
          recentCheckIns: 0,
          weeklyCheckIns: 0,
          totalCheckIns: 0,
          popularityUpdatedAt: now
        });
        placeUpdateCount++;
      }
    });
    
    await batch.commit();
    console.log(`✅ Updated popularity scores for ${eventUpdateCount} events and ${placeUpdateCount} places`);
    
    return { 
      success: true, 
      eventsUpdated: eventUpdateCount,
      placesUpdated: placeUpdateCount,
      totalUpdated: eventUpdateCount + placeUpdateCount
    };
    
  } catch (error) {
    console.error('❌ Error updating event popularity:', error);
    throw error;
  }
});

// HTTP function to get trending events
exports.getTrendingEvents = functions.https.onRequest(async (req, res) => {
  console.log('📈 Getting trending events...');
  
  try {
    const db = admin.firestore();
    const { city, limit = 20, timeframe = 'recent' } = req.query;
    
    let query = db.collection('events');
    
    // Filter by city if provided
    if (city) {
      query = query.where('city', '==', city);
    }
    
    // Order by popularity score (descending)
    query = query.orderBy('popularityScore', 'desc').limit(parseInt(limit));
    
    const eventsSnapshot = await query.get();
    
    const trendingEvents = eventsSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        eventName: data.eventName,
        venueName: data.venueName,
        eventLocation: data.eventLocation,
        city: data.city,
        imageUrl: data.imageUrl,
        popularityScore: data.popularityScore || 0,
        recentCheckIns: data.recentCheckIns || 0,
        weeklyCheckIns: data.weeklyCheckIns || 0,
        totalCheckIns: data.totalCheckIns || 0,
        coordinates: data.coordinates
      };
    });
    
    console.log(`📊 Returning ${trendingEvents.length} trending events`);
    
    res.status(200).json({
      success: true,
      events: trendingEvents,
      totalCount: trendingEvents.length,
      city: city || 'all',
      timeframe: timeframe
    });
    
  } catch (error) {
    console.error('❌ Error getting trending events:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// ENHANCED: Universal popularity update function for both events and places
exports.updatePopularityOnCheckIn = functions.firestore
  .document('checkIns/{checkInId}')
  .onCreate(async (snap, context) => {
    const checkInData = snap.data();
    const itemId = checkInData.eventId; // Note: eventId field is used for both events and places
    const userId = checkInData.userId;
    
    if (!itemId || !userId) {
      console.log('⚠️ Check-in created without itemId or userId');
      return null;
    }
    
    console.log(`🔥 New check-in created for item ${itemId} by user ${userId}, updating popularity and user history...`);
    
    try {
      const db = admin.firestore();
      let itemType = null;
      
      // Try events collection first
      const eventRef = db.collection('events').doc(itemId);
      const eventDoc = await eventRef.get();
      
      if (eventDoc.exists) {
        // It's an event
        itemType = 'event';
        await updateItemPopularity(eventRef, eventDoc.data(), 'event', itemId);
      } else {
        // Try places collection
        const placeRef = db.collection('places').doc(itemId);
        const placeDoc = await placeRef.get();
        
        if (placeDoc.exists) {
          // It's a place
          itemType = 'place';
          await updateItemPopularity(placeRef, placeDoc.data(), 'place', itemId);
        } else {
          console.log(`⚠️ Neither event nor place found with ID ${itemId}`);
          return null;
        }
      }
      
      // ENHANCED: Update user's check-in history
      if (itemType) {
        await updateUserCheckInHistory(userId, itemId, itemType, true);
      }
      
      return null;
    } catch (error) {
      console.error(`❌ Error updating popularity for ${itemId}:`, error);
      return null;
    }
  });

// ENHANCED: Universal popularity update function for check-outs
exports.updatePopularityOnCheckOut = functions.firestore
  .document('checkIns/{checkInId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    // Only process when a check-in becomes inactive (checked out)
    if (beforeData.isActive === true && afterData.isActive === false) {
      const itemId = afterData.eventId;
      
      if (!itemId) {
        console.log('⚠️ Check-out processed without itemId');
        return null;
      }
      
      console.log(`🔥 Check-out processed for item ${itemId}, updating popularity...`);
      
      try {
        const db = admin.firestore();
        
        // Try events collection first
        const eventRef = db.collection('events').doc(itemId);
        const eventDoc = await eventRef.get();
        
        if (eventDoc.exists) {
          // It's an event
          await updateItemPopularity(eventRef, eventDoc.data(), 'event', itemId, false);
          // Note: We keep items in user history for historical purposes on check-out
          await updateUserCheckInHistory(afterData.userId, itemId, 'event', false);
        } else {
          // Try places collection
          const placeRef = db.collection('places').doc(itemId);
          const placeDoc = await placeRef.get();
          
          if (placeDoc.exists) {
            // It's a place
            await updateItemPopularity(placeRef, placeDoc.data(), 'place', itemId, false);
            // Note: We keep items in user history for historical purposes on check-out
            await updateUserCheckInHistory(afterData.userId, itemId, 'place', false);
          } else {
            console.log(`⚠️ Neither event nor place found with ID ${itemId}`);
          }
        }
        
        return null;
      } catch (error) {
        console.error(`❌ Error updating popularity on check-out for ${itemId}:`, error);
        return null;
      }
    }
    
    return null;
  });

// Helper function to update popularity for events or places
async function updateItemPopularity(itemRef, itemData, itemType, itemId, isCheckIn = true) {
  const currentScore = itemData.popularityScore || 0;
  const currentRecent = itemData.recentCheckIns || 0;
  const currentTotal = itemData.totalCheckIns || 0;
  
  // Calculate new values
  let newRecentCount, newTotalCount, newScore;
  
  if (isCheckIn) {
    // Check-in: increment counters
    newRecentCount = currentRecent + 1;
    newTotalCount = currentTotal + 1;
    newScore = currentScore + 5; // Add 5 points for recent check-in
  } else {
    // Check-out: decrement recent count only (keep total for historical data)
    newRecentCount = Math.max(0, currentRecent - 1);
    newTotalCount = currentTotal; // Keep total check-ins for historical purposes
    newScore = Math.max(0, currentScore - 2); // Subtract 2 points for check-out
  }
  
  await itemRef.update({
    popularityScore: newScore,
    recentCheckIns: newRecentCount,
    totalCheckIns: newTotalCount,
    popularityUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  console.log(`✅ Updated ${itemType} ${itemId} popularity: score ${currentScore} → ${newScore}, recent ${currentRecent} → ${newRecentCount}`);
}

// ENHANCED: Helper function to update user's check-in history
async function updateUserCheckInHistory(userId, itemId, itemType, isCheckIn = true) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(userId);
  
  console.log(`🔄 Updating user ${userId} check-in history for ${itemType} ${itemId} (isCheckIn: ${isCheckIn})`);
  
  try {
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      console.log(`⚠️ User ${userId} not found, cannot update check-in history`);
      return;
    }
    
    const userData = userDoc.data();
    const checkInHistory = userData.checkInHistory || { events: [], places: [] };
    
    // Ensure arrays exist
    if (!checkInHistory.events) checkInHistory.events = [];
    if (!checkInHistory.places) checkInHistory.places = [];
    
    const targetArray = itemType === 'event' ? checkInHistory.events : checkInHistory.places;
    
    if (isCheckIn) {
      // Add to history if not already present
      if (!targetArray.includes(itemId)) {
        targetArray.push(itemId);
        console.log(`➕ Added ${itemType} ${itemId} to user history`);
      } else {
        console.log(`ℹ️ ${itemType} ${itemId} already in user history`);
      }
    } else {
      // Note: We generally don't remove from history on check-out to preserve historical data
      // But we could implement different logic here if needed
      console.log(`ℹ️ Check-out processed, keeping ${itemType} ${itemId} in user history for historical purposes`);
    }
    
    // Update the user document
    await userRef.update({
      checkInHistory: {
        events: checkInHistory.events,
        places: checkInHistory.places,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`✅ Updated user ${userId} check-in history: ${checkInHistory.events.length} events, ${checkInHistory.places.length} places`);
    
  } catch (error) {
    console.error(`❌ Error updating user check-in history:`, error);
  }
}

// MARK: - Location-based Event Discovery

// HTTP function to get nearby events
exports.getNearbyEvents = functions.https.onRequest(async (req, res) => {
  console.log('📍 Getting nearby events...');
  
  try {
    const { latitude, longitude, radius = 40000, limit = 50 } = req.query; // radius in meters, default 25 miles
    
    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        error: 'Latitude and longitude are required'
      });
    }
    
    const userLat = parseFloat(latitude);
    const userLng = parseFloat(longitude);
    const radiusInMeters = parseInt(radius);
    
    console.log(`📍 Searching for events within ${radiusInMeters}m of (${userLat}, ${userLng})`);
    
    const db = admin.firestore();
    
    // Get all events with coordinates
    const eventsSnapshot = await db.collection('events')
      .where('coordinates', '!=', null)
      .limit(parseInt(limit) * 2) // Get more to filter by distance
      .get();
    
    const nearbyEvents = [];
    
    eventsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const coordinates = data.coordinates;
      
      if (coordinates && coordinates.latitude && coordinates.longitude) {
        const distance = calculateDistance(
          userLat, userLng,
          coordinates.latitude, coordinates.longitude
        );
        
        if (distance <= radiusInMeters) {
          nearbyEvents.push({
            id: doc.id,
            ...data,
            distanceMeters: Math.round(distance),
            distanceMiles: Math.round(distance * 0.000621371 * 10) / 10
          });
        }
      }
    });
    
    // Sort by distance, then by popularity
    nearbyEvents.sort((a, b) => {
      const distanceDiff = a.distanceMeters - b.distanceMeters;
      if (distanceDiff !== 0) return distanceDiff;
      return (b.popularityScore || 0) - (a.popularityScore || 0);
    });
    
    // Limit results
    const limitedEvents = nearbyEvents.slice(0, parseInt(limit));
    
    console.log(`📊 Found ${limitedEvents.length} events within ${radiusInMeters}m`);
    
    res.status(200).json({
      success: true,
      events: limitedEvents,
      totalCount: limitedEvents.length,
      searchCenter: { latitude: userLat, longitude: userLng },
      radiusMeters: radiusInMeters
    });
    
  } catch (error) {
    console.error('❌ Error getting nearby events:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Helper function to calculate distance between two coordinates using Haversine formula
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c; // Distance in meters
}

// ENHANCED: Get user's complete check-in analytics
exports.getUserCheckInAnalytics = functions.https.onRequest(async (req, res) => {
  console.log('📊 Getting user check-in analytics...');
  
  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'userId is required'
      });
    }
    
    const db = admin.firestore();
    
    // Get user's check-in history from user document
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }
    
    const userData = userDoc.data();
    const checkInHistory = userData.checkInHistory || { events: [], places: [] };
    
    // Get current active check-ins from checkIns collection
    const activeCheckInsSnapshot = await db.collection('checkIns')
      .where('userId', '==', userId)
      .where('isActive', '==', true)
      .get();
    
    const currentCheckIns = activeCheckInsSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        itemId: data.eventId,
        checkedInAt: data.checkedInAt,
        type: 'unknown' // Will be determined by checking events/places collections
      };
    });
    
    // Fetch details for historical events and places
    const historicalEvents = [];
    const historicalPlaces = [];
    
    if (checkInHistory.events && checkInHistory.events.length > 0) {
      const eventPromises = checkInHistory.events.map(async (eventId) => {
        const eventDoc = await db.collection('events').doc(eventId).get();
        if (eventDoc.exists) {
          return { id: eventId, ...eventDoc.data() };
        }
        return null;
      });
      
      const events = await Promise.all(eventPromises);
      historicalEvents.push(...events.filter(e => e !== null));
    }
    
    if (checkInHistory.places && checkInHistory.places.length > 0) {
      const placePromises = checkInHistory.places.map(async (placeId) => {
        const placeDoc = await db.collection('places').doc(placeId).get();
        if (placeDoc.exists) {
          return { id: placeId, ...placeDoc.data() };
        }
        return null;
      });
      
      const places = await Promise.all(placePromises);
      historicalPlaces.push(...places.filter(p => p !== null));
    }
    
    // Calculate analytics
    const analytics = {
      totalHistoricalCheckIns: historicalEvents.length + historicalPlaces.length,
      totalEvents: historicalEvents.length,
      totalPlaces: historicalPlaces.length,
      currentActiveCheckIns: currentCheckIns.length,
      
      // Favorite categories
      favoriteEventCategories: calculateTopCategories(historicalEvents, 'eventCategory'),
      favoriteCities: calculateTopCities([...historicalEvents, ...historicalPlaces]),
      
      // Recent activity
      recentEvents: historicalEvents.slice(-5),
      recentPlaces: historicalPlaces.slice(-5),
      
      // Current status
      currentlyCheckedInto: currentCheckIns
    };
    
    console.log(`📊 User ${userId} analytics: ${analytics.totalHistoricalCheckIns} total check-ins`);
    
    res.status(200).json({
      success: true,
      userId: userId,
      analytics: analytics,
      checkInHistory: checkInHistory,
      userData: {
        firstName: userData.firstName,
        city: userData.city,
        createdAt: userData.createdAt
      }
    });
    
  } catch (error) {
    console.error('❌ Error getting user analytics:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Helper functions for analytics
function calculateTopCategories(items, categoryField) {
  const categoryCount = {};
  items.forEach(item => {
    const category = item[categoryField];
    if (category) {
      categoryCount[category] = (categoryCount[category] || 0) + 1;
    }
  });
  
  return Object.entries(categoryCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([category, count]) => ({ category, count }));
}

function calculateTopCities(items) {
  const cityCount = {};
  items.forEach(item => {
    const city = item.city;
    if (city) {
      cityCount[city] = (cityCount[city] || 0) + 1;
    }
  });
  
  return Object.entries(cityCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([city, count]) => ({ city, count }));
}

// MIGRATION: Convert Adalo check-in arrays to Firebase checkIns collection
exports.migrateCheckInData = functions.https.onRequest(async (req, res) => {
  console.log('🔄 Starting migration of check-in data from Adalo arrays to checkIns collection...');
  
  try {
    const db = admin.firestore();
    const { dryRun = false } = req.query;
    
    if (dryRun) {
      console.log('📊 DRY RUN MODE - No data will be written');
    }
    
    const results = {
      eventsProcessed: 0,
      placesProcessed: 0,
      checkInsCreated: 0,
      errors: [],
      dryRun: dryRun
    };
    
    // Step 1: Process Events with attendeeIds
    console.log('📅 Step 1: Processing events with attendeeIds...');
    const eventsSnapshot = await db.collection('events').get();
    
    for (const eventDoc of eventsSnapshot.docs) {
      try {
        const eventData = eventDoc.data();
        const eventId = eventDoc.id;
        const attendeeIds = eventData.attendeeIds || [];
        
        if (attendeeIds.length > 0) {
          console.log(`📅 Event "${eventData.eventName || eventData.name}" has ${attendeeIds.length} attendees`);
          
          for (const adaloUserId of attendeeIds) {
            // Find Firebase user by original Adalo ID
            const userQuery = await db.collection('users')
              .where('adaloId', '==', parseInt(adaloUserId))
              .limit(1)
              .get();
            
            if (!userQuery.empty) {
              const userDoc = userQuery.docs[0];
              const firebaseUserId = userDoc.id;
              const userData = userDoc.data();
              
              // Check if check-in already exists
              const existingCheckIn = await db.collection('checkIns')
                .where('userId', '==', firebaseUserId)
                .where('eventId', '==', eventId)
                .limit(1)
                .get();
              
              if (existingCheckIn.empty) {
                const checkInData = {
                  userId: firebaseUserId,
                  eventId: eventId,
                  checkedInAt: eventData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
                  checkedOutAt: null,
                  isActive: false, // Historical check-ins are inactive by default
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  migratedFrom: 'adalo',
                  originalAdaloUserId: adaloUserId
                };
                
                if (!dryRun) {
                  await db.collection('checkIns').add(checkInData);
                }
                
                results.checkInsCreated++;
                console.log(`✅ Created check-in: ${userData.firstName} → ${eventData.eventName}`);
              } else {
                console.log(`⚠️ Check-in already exists: ${userData.firstName} → ${eventData.eventName}`);
              }
            } else {
              console.log(`⚠️ No Firebase user found for Adalo ID ${adaloUserId}`);
            }
          }
        }
        
        results.eventsProcessed++;
      } catch (error) {
        console.error(`❌ Error processing event ${eventDoc.id}:`, error);
        results.errors.push({
          type: 'event',
          id: eventDoc.id,
          error: error.message
        });
      }
    }
    
    // Step 2: Process Places with visitorIds
    console.log('📍 Step 2: Processing places with visitorIds...');
    const placesSnapshot = await db.collection('places').get();
    
    for (const placeDoc of placesSnapshot.docs) {
      try {
        const placeData = placeDoc.data();
        const placeId = placeDoc.id;
        const visitorIds = placeData.visitorIds || [];
        
        if (visitorIds.length > 0) {
          console.log(`📍 Place "${placeData.placeName || placeData.name}" has ${visitorIds.length} visitors`);
          
          for (const adaloUserId of visitorIds) {
            // Find Firebase user by original Adalo ID
            const userQuery = await db.collection('users')
              .where('adaloId', '==', parseInt(adaloUserId))
              .limit(1)
              .get();
            
            if (!userQuery.empty) {
              const userDoc = userQuery.docs[0];
              const firebaseUserId = userDoc.id;
              const userData = userDoc.data();
              
              // Check if check-in already exists
              const existingCheckIn = await db.collection('checkIns')
                .where('userId', '==', firebaseUserId)
                .where('eventId', '==', placeId) // Note: using eventId field for both events and places
                .limit(1)
                .get();
              
              if (existingCheckIn.empty) {
                const checkInData = {
                  userId: firebaseUserId,
                  eventId: placeId, // Note: using eventId field for both events and places
                  checkedInAt: placeData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
                  checkedOutAt: null,
                  isActive: false, // Historical check-ins are inactive by default
                  createdAt: admin.firestore.FieldValue.serverTimestamp(),
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  migratedFrom: 'adalo',
                  originalAdaloUserId: adaloUserId,
                  itemType: 'place' // Add identifier for places
                };
                
                if (!dryRun) {
                  await db.collection('checkIns').add(checkInData);
                }
                
                results.checkInsCreated++;
                console.log(`✅ Created check-in: ${userData.firstName} → ${placeData.placeName}`);
              } else {
                console.log(`⚠️ Check-in already exists: ${userData.firstName} → ${placeData.placeName}`);
              }
            } else {
              console.log(`⚠️ No Firebase user found for Adalo ID ${adaloUserId}`);
            }
          }
        }
        
        results.placesProcessed++;
      } catch (error) {
        console.error(`❌ Error processing place ${placeDoc.id}:`, error);
        results.errors.push({
          type: 'place',
          id: placeDoc.id,
          error: error.message
        });
      }
    }
    
    // Step 3: Update popularity scores based on migrated data
    if (!dryRun && results.checkInsCreated > 0) {
      console.log('📊 Step 3: Updating popularity scores...');
      
      // Trigger the popularity update function
      try {
        // We'll call the existing updatePopularityScores function
        const { updatePopularityScores } = require('./index');
        // Note: This would need to be refactored to be callable internally
        console.log('📊 Popularity scores will be updated on next scheduled run');
      } catch (error) {
        console.log('⚠️ Could not trigger popularity update automatically');
      }
    }
    
    console.log('🎉 Migration completed!', results);
    
    res.status(200).json({
      success: true,
      message: `Migration completed - Created ${results.checkInsCreated} check-in records`,
      results: results,
      nextSteps: [
        '1. Review the migrated check-ins in Firebase Console',
        '2. Test the app to see check-in counts display properly',
        '3. Run the popularity score update if needed',
        '4. Consider running this migration again without dryRun if results look good'
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

// Helper function to get current Firebase data status
exports.getCheckInDataStatus = functions.https.onRequest(async (req, res) => {
  console.log('📊 Checking current check-in data status...');
  
  try {
    const db = admin.firestore();
    
    // Count documents in each collection
    const [eventsSnapshot, placesSnapshot, checkInsSnapshot, usersSnapshot] = await Promise.all([
      db.collection('events').get(),
      db.collection('places').get(),
      db.collection('checkIns').get(),
      db.collection('users').get()
    ]);
    
    // Analyze events with attendeeIds
    let eventsWithAttendees = 0;
    let totalAttendeeIds = 0;
    eventsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.attendeeIds && Array.isArray(data.attendeeIds) && data.attendeeIds.length > 0) {
        eventsWithAttendees++;
        totalAttendeeIds += data.attendeeIds.length;
      }
    });
    
    // Analyze places with visitorIds
    let placesWithVisitors = 0;
    let totalVisitorIds = 0;
    placesSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.visitorIds && Array.isArray(data.visitorIds) && data.visitorIds.length > 0) {
        placesWithVisitors++;
        totalVisitorIds += data.visitorIds.length;
      }
    });
    
    // Analyze existing check-ins
    let activeCheckIns = 0;
    let historicalCheckIns = 0;
    checkInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.isActive) {
        activeCheckIns++;
      } else {
        historicalCheckIns++;
      }
    });
    
    const status = {
      collections: {
        events: eventsSnapshot.size,
        places: placesSnapshot.size,
        users: usersSnapshot.size,
        checkIns: checkInsSnapshot.size
      },
      adaloData: {
        eventsWithAttendees: eventsWithAttendees,
        totalAttendeeIds: totalAttendeeIds,
        placesWithVisitors: placesWithVisitors,
        totalVisitorIds: totalVisitorIds
      },
      checkInData: {
        totalCheckIns: checkInsSnapshot.size,
        activeCheckIns: activeCheckIns,
        historicalCheckIns: historicalCheckIns
      },
      migrationNeeded: checkInsSnapshot.size === 0 && (totalAttendeeIds > 0 || totalVisitorIds > 0)
    };
    
    console.log('📊 Data status:', status);
    
    res.status(200).json({
      success: true,
      status: status,
      recommendation: status.migrationNeeded ? 
        'Migration needed - Run /migrateCheckInData?dryRun=true first to preview' :
        'Check-in data looks good!'
    });
    
  } catch (error) {
    console.error('❌ Error checking data status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// INSPECTION: Detailed Firebase data inspection
exports.inspectDetailedData = functions.https.onRequest(async (req, res) => {
  console.log('🔍 Starting detailed Firebase data inspection...');
  
  try {
    const db = admin.firestore();
    const { showSamples = true, eventId = null } = req.query;
    
    const results = {
      summary: {},
      checkInSamples: [],
      eventSamples: [],
      placeSamples: [],
      userSamples: []
    };
    
    // Get collection counts
    const [checkInsSnapshot, eventsSnapshot, placesSnapshot, usersSnapshot] = await Promise.all([
      db.collection('checkIns').get(),
      db.collection('events').get(),
      db.collection('places').get(),
      db.collection('users').get()
    ]);
    
    results.summary = {
      checkIns: checkInsSnapshot.size,
      events: eventsSnapshot.size,
      places: placesSnapshot.size,
      users: usersSnapshot.size
    };
    
    // Analyze check-ins in detail
    let activeCheckIns = 0;
    let migratedCheckIns = 0;
    const eventCheckInCounts = {};
    const userCheckInCounts = {};
    
    checkInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      
      if (data.isActive) activeCheckIns++;
      if (data.migratedFrom === 'adalo') migratedCheckIns++;
      
      // Count by event
      if (data.eventId) {
        eventCheckInCounts[data.eventId] = (eventCheckInCounts[data.eventId] || 0) + 1;
      }
      
      // Count by user
      if (data.userId) {
        userCheckInCounts[data.userId] = (userCheckInCounts[data.userId] || 0) + 1;
      }
    });
    
    results.checkInAnalysis = {
      total: checkInsSnapshot.size,
      active: activeCheckIns,
      historical: checkInsSnapshot.size - activeCheckIns,
      migratedFromAdalo: migratedCheckIns,
      uniqueEvents: Object.keys(eventCheckInCounts).length,
      uniqueUsers: Object.keys(userCheckInCounts).length,
      topEvents: Object.entries(eventCheckInCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([eventId, count]) => ({ eventId, checkInCount: count })),
      topUsers: Object.entries(userCheckInCounts)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([userId, count]) => ({ userId, checkInCount: count }))
    };
    
    if (showSamples) {
      // Get sample check-ins
      const sampleCheckIns = checkInsSnapshot.docs.slice(0, 5);
      for (const doc of sampleCheckIns) {
        const data = doc.data();
        
        // Get user info
        let userInfo = null;
        if (data.userId) {
          const userDoc = await db.collection('users').doc(data.userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            userInfo = {
              firstName: userData.firstName,
              adaloId: userData.adaloId
            };
          }
        }
        
        // Get event/place info
        let itemInfo = null;
        if (data.eventId) {
          // Try events first
          const eventDoc = await db.collection('events').doc(data.eventId).get();
          if (eventDoc.exists) {
            const eventData = eventDoc.data();
            itemInfo = {
              type: 'event',
              name: eventData.eventName || eventData.name,
              attendeeIds: eventData.attendeeIds ? eventData.attendeeIds.length : 0,
              popularityScore: eventData.popularityScore
            };
          } else {
            // Try places
            const placeDoc = await db.collection('places').doc(data.eventId).get();
            if (placeDoc.exists) {
              const placeData = placeDoc.data();
              itemInfo = {
                type: 'place',
                name: placeData.placeName || placeData.name,
                visitorIds: placeData.visitorIds ? placeData.visitorIds.length : 0,
                popularityScore: placeData.popularityScore
              };
            }
          }
        }
        
        results.checkInSamples.push({
          id: doc.id,
          userId: data.userId,
          eventId: data.eventId,
          isActive: data.isActive,
          checkedInAt: data.checkedInAt,
          migratedFrom: data.migratedFrom,
          userInfo: userInfo,
          itemInfo: itemInfo
        });
      }
      
      // Get sample events with their check-in counts
      const sampleEvents = eventsSnapshot.docs.slice(0, 5);
      for (const doc of sampleEvents) {
        const data = doc.data();
        const eventId = doc.id;
        const checkInCount = eventCheckInCounts[eventId] || 0;
        
        results.eventSamples.push({
          id: eventId,
          name: data.eventName || data.name,
          attendeeIds: data.attendeeIds ? data.attendeeIds.length : 0,
          actualCheckIns: checkInCount,
          popularityScore: data.popularityScore,
          recentCheckIns: data.recentCheckIns,
          city: data.city,
          createdAt: data.createdAt
        });
      }
      
      // Get sample places
      const samplePlaces = placesSnapshot.docs.slice(0, 5);
      for (const doc of samplePlaces) {
        const data = doc.data();
        const placeId = doc.id;
        const checkInCount = eventCheckInCounts[placeId] || 0;
        
        results.placeSamples.push({
          id: placeId,
          name: data.placeName || data.name,
          visitorIds: data.visitorIds ? data.visitorIds.length : 0,
          actualCheckIns: checkInCount,
          popularityScore: data.popularityScore,
          recentCheckIns: data.recentCheckIns,
          city: data.city
        });
      }
    }
    
    // If specific eventId requested, get detailed info
    if (eventId) {
      const eventCheckIns = await db.collection('checkIns')
        .where('eventId', '==', eventId)
        .get();
      
      const eventDoc = await db.collection('events').doc(eventId).get();
      const placeDoc = await db.collection('places').doc(eventId).get();
      
      results.specificItem = {
        id: eventId,
        checkInCount: eventCheckIns.size,
        checkIns: eventCheckIns.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          checkedInAt: doc.data().checkedInAt?.toDate()
        })),
        itemData: eventDoc.exists ? 
          { type: 'event', ...eventDoc.data() } : 
          (placeDoc.exists ? { type: 'place', ...placeDoc.data() } : null)
      };
    }
    
    console.log('✅ Detailed inspection complete');
    
    res.status(200).json({
      success: true,
      results: results,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error in detailed inspection:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// NEW: Mutual Compatibility Filter Function
exports.getCompatibleMembers = functions.https.onCall(async (data, context) => {
  console.log('🔗 Getting compatible members...');
  
  try {
    // Check authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'User must be authenticated to get compatible members.'
      );
    }
    
    const currentUserId = data.currentUserId;
    const limitCount = data.limit || 50;
    const page = data.page || 0;
    
    if (!currentUserId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'currentUserId is required.'
      );
    }
    
    const db = admin.firestore();
    
    // Get current user's preferences
    const currentUserDoc = await db.collection('users').doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Current user not found.'
      );
    }
    
    const currentUser = currentUserDoc.data();
    const currentUserGender = currentUser.gender?.toLowerCase()?.trim() || '';
    const currentUserAttractedTo = currentUser.attractedTo?.toLowerCase()?.trim() || '';
    
    console.log(`🔗 Current user: ${currentUser.firstName} (gender: ${currentUserGender}, attracted to: ${currentUserAttractedTo})`);
    
    // Get all members (excluding current user)
    const membersSnapshot = await db.collection('members')
      .get();
    
    const compatibleMembers = [];
    let processedCount = 0;
    
    for (const memberDoc of membersSnapshot.docs) {
      const member = memberDoc.data();
      const memberId = memberDoc.id;
      
      // Skip current user
      if (memberId === currentUserId || member.userId === currentUserId) {
        continue;
      }
      
      processedCount++;
      
      const memberGender = member.gender?.toLowerCase()?.trim() || '';
      const memberAttractedTo = member.attractedTo?.toLowerCase()?.trim() || '';
      
      // Check mutual compatibility
      const userAttractedToMember = isAttractedTo(currentUserAttractedTo, memberGender);
      const memberAttractedToUser = isAttractedTo(memberAttractedTo, currentUserGender);
      
      if (userAttractedToMember && memberAttractedToUser) {
        // Calculate compatibility score
        const compatibilityScore = calculateCompatibilityScore(member, currentUser);
        
        compatibleMembers.push({
          ...member,
          id: memberId,
          compatibilityScore: compatibilityScore,
          mutuallyCompatible: true
        });
        
        console.log(`✅ Compatible: ${member.firstName} (gender: ${memberGender}, attracted to: ${memberAttractedTo}) - Score: ${compatibilityScore}`);
      } else {
        console.log(`❌ Not compatible: ${member.firstName} (gender: ${memberGender}, attracted to: ${memberAttractedTo})`);
      }
    }
    
    // Sort by compatibility score
    compatibleMembers.sort((a, b) => b.compatibilityScore - a.compatibilityScore);
    
    // Apply pagination
    const startIndex = page * limitCount;
    const endIndex = startIndex + limitCount;
    const paginatedMembers = compatibleMembers.slice(startIndex, endIndex);
    
    console.log(`🔗 Found ${compatibleMembers.length} compatible members out of ${processedCount} total members`);
    console.log(`📄 Returning page ${page} with ${paginatedMembers.length} members`);
    
    return {
      success: true,
      members: paginatedMembers,
      totalCompatible: compatibleMembers.length,
      totalProcessed: processedCount,
      page: page,
      hasMore: endIndex < compatibleMembers.length
    };
    
  } catch (error) {
    console.error('❌ Error in getCompatibleMembers:', error);
    throw new functions.https.HttpsError(
      'internal',
      error.message
    );
  }
});

// Helper function for attraction checking (server-side)
function isAttractedTo(userAttractedTo, personGender) {
  if (!userAttractedTo || userAttractedTo.trim() === '') {
    return true; // No preference = open to everyone
  }
  
  if (!personGender || personGender.trim() === '') {
    return true; // No gender specified = assume compatibility
  }
  
  const attractedTo = userAttractedTo.toLowerCase().trim();
  const gender = personGender.toLowerCase().trim();
  
  // Handle "everyone" cases
  if (attractedTo === 'everyone' || 
      attractedTo === 'all' || 
      attractedTo === 'anyone' || 
      attractedTo === 'both' ||
      attractedTo === 'all genders') {
    return true;
  }
  
  // Check female attraction
  if (attractedTo.includes('women') || 
      attractedTo.includes('woman') || 
      attractedTo.includes('female') ||
      attractedTo.includes('girls') ||
      attractedTo.includes('girl')) {
    if (gender.includes('woman') || 
        gender.includes('female') || 
        gender.includes('girl')) {
      return true;
    }
  }
  
  // Check male attraction
  if (attractedTo.includes('men') || 
      attractedTo.includes('man') || 
      attractedTo.includes('male') ||
      attractedTo.includes('guys') ||
      attractedTo.includes('guy')) {
    if (gender.includes('man') || 
        gender.includes('male') || 
        gender.includes('guy')) {
      return true;
    }
  }
  
  // Check non-binary and other identities
  if (attractedTo.includes('non-binary') ||
      attractedTo.includes('nonbinary') ||
      attractedTo.includes('enby') ||
      attractedTo.includes('genderfluid') ||
      attractedTo.includes('genderqueer') ||
      attractedTo.includes('transgender') ||
      attractedTo.includes('trans')) {
    if (gender.includes('non-binary') ||
        gender.includes('nonbinary') ||
        gender.includes('enby') ||
        gender.includes('genderfluid') ||
        gender.includes('genderqueer') ||
        gender.includes('transgender') ||
        gender.includes('trans')) {
      return true;
    }
  }
  
  return false;
}

// Helper function for compatibility scoring (server-side)
function calculateCompatibilityScore(member, currentUser) {
  let score = 0;
  
  // Profile completeness (0-30 points)
  let completenessScore = 0;
  const totalFields = 6;
  
  if (member.id && member.id.trim() !== '') completenessScore++;
  if (member.age) completenessScore++;
  if (member.city && member.city.trim() !== '') completenessScore++;
  if (member.gender && member.gender.trim() !== '') completenessScore++;
  if (member.approachTip && member.approachTip.trim() !== '') completenessScore++;
  if (member.instagramHandle && member.instagramHandle.trim() !== '') completenessScore++;
  
  score += (completenessScore / totalFields) * 30;
  
  // Age compatibility (0-25 points)
  if (member.age && currentUser.age) {
    const ageDiff = Math.abs(member.age - currentUser.age);
    const ageScore = Math.max(0, 25 - ageDiff);
    score += ageScore;
  }
  
  // Location compatibility (0-20 points)
  if (member.city && currentUser.city) {
    const memberCity = member.city.toLowerCase();
    const userCity = currentUser.city.toLowerCase();
    
    if (memberCity === userCity) {
      score += 20;
    } else if (memberCity.includes(userCity) || userCity.includes(memberCity)) {
      score += 15;
    }
  }
  
  // Mutual compatibility already verified (25 points)
  score += 25;
  
  // Profile activity (0-10 points)
  if (member.instagramHandle && member.instagramHandle.trim() !== '') {
    score += 5;
  }
  if (member.approachTip && member.approachTip.trim() !== '') {
    score += 5;
  }
  
  return Math.round(score);
}