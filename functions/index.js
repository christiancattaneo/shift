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

// MARK: - Event Ranking and Popularity System

// Cloud function to calculate and update event popularity scores
exports.updateEventPopularity = functions.pubsub.schedule('every 30 minutes').onRun(async (context) => {
  console.log('🔥 Starting event popularity update...');
  
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
    
    console.log(`📊 Found ${recentCheckInsSnapshot.size} check-ins in last 24h`);
    console.log(`📊 Found ${weeklyCheckInsSnapshot.size} check-ins in last week`);
    
    // Calculate popularity scores by event
    const eventPopularity = {};
    
    // Weight recent check-ins more heavily
    recentCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const eventId = data.eventId;
      if (!eventPopularity[eventId]) {
        eventPopularity[eventId] = { recent: 0, weekly: 0, total: 0 };
      }
      eventPopularity[eventId].recent += 1;
    });
    
    weeklyCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const eventId = data.eventId;
      if (!eventPopularity[eventId]) {
        eventPopularity[eventId] = { recent: 0, weekly: 0, total: 0 };
      }
      eventPopularity[eventId].weekly += 1;
    });
    
    // Get total check-ins for each event
    const allCheckInsSnapshot = await db.collection('checkIns')
      .where('isActive', '==', true)
      .get();
    
    allCheckInsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      const eventId = data.eventId;
      if (!eventPopularity[eventId]) {
        eventPopularity[eventId] = { recent: 0, weekly: 0, total: 0 };
      }
      eventPopularity[eventId].total += 1;
    });
    
    // Calculate composite popularity score
    // Formula: (recent * 5) + (weekly * 2) + (total * 0.5)
    const popularityScores = {};
    for (const [eventId, stats] of Object.entries(eventPopularity)) {
      const score = (stats.recent * 5) + (stats.weekly * 2) + (stats.total * 0.5);
      popularityScores[eventId] = {
        score: score,
        recentCheckIns: stats.recent,
        weeklyCheckIns: stats.weekly,
        totalCheckIns: stats.total,
        lastUpdated: now
      };
    }
    
    console.log(`📈 Calculated popularity for ${Object.keys(popularityScores).length} events`);
    
    // Update events with popularity scores
    const batch = db.batch();
    let updateCount = 0;
    
    for (const [eventId, popularity] of Object.entries(popularityScores)) {
      const eventRef = db.collection('events').doc(eventId);
      batch.update(eventRef, {
        popularityScore: popularity.score,
        recentCheckIns: popularity.recentCheckIns,
        weeklyCheckIns: popularity.weeklyCheckIns,
        totalCheckIns: popularity.totalCheckIns,
        popularityUpdatedAt: popularity.lastUpdated
      });
      updateCount++;
    }
    
    // Also reset popularity for events with no recent activity
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
        updateCount++;
      }
    });
    
    await batch.commit();
    console.log(`✅ Updated popularity scores for ${updateCount} events`);
    
    return { success: true, eventsUpdated: updateCount };
    
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

// HTTP function to update a single event's popularity when new check-in happens
exports.updateEventPopularityOnCheckIn = functions.firestore
  .document('checkIns/{checkInId}')
  .onCreate(async (snap, context) => {
    const checkInData = snap.data();
    const eventId = checkInData.eventId;
    
    if (!eventId) {
      console.log('⚠️ Check-in created without eventId');
      return null;
    }
    
    console.log(`🔥 New check-in created for event ${eventId}, updating popularity...`);
    
    try {
      const db = admin.firestore();
      const eventRef = db.collection('events').doc(eventId);
      
      // Get current event data
      const eventDoc = await eventRef.get();
      if (!eventDoc.exists) {
        console.log(`⚠️ Event ${eventId} not found`);
        return null;
      }
      
      const eventData = eventDoc.data();
      const currentScore = eventData.popularityScore || 0;
      const currentRecent = eventData.recentCheckIns || 0;
      const currentTotal = eventData.totalCheckIns || 0;
      
      // Increment counters and recalculate score
      const newRecentCount = currentRecent + 1;
      const newTotalCount = currentTotal + 1;
      const newScore = currentScore + 5; // Add 5 points for recent check-in
      
      await eventRef.update({
        popularityScore: newScore,
        recentCheckIns: newRecentCount,
        totalCheckIns: newTotalCount,
        popularityUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`✅ Updated event ${eventId} popularity: score ${currentScore} → ${newScore}`);
      
      return null;
    } catch (error) {
      console.error(`❌ Error updating event popularity for ${eventId}:`, error);
      return null;
    }
  });

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