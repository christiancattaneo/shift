const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'shift-12948'
});

const db = admin.firestore();
// Bucket will be determined dynamically in functions

// Configuration
const CONFIG = {
  localImagesDir: './all_adalo_images',
  collections: {
    users: {
      localDir: 'users',
      firestoreCollection: 'users',
      imageField: 'profileImageUrl',
      storagePrefix: 'profile_images/'
    },
    events: {
      localDir: 'events', 
      firestoreCollection: 'events',
      imageField: 'imageUrl',
      storagePrefix: 'event_images/'
    },
    places: {
      localDir: 'places',
      firestoreCollection: 'places', 
      imageField: 'imageUrl',
      storagePrefix: 'place_images/'
    }
  }
};

// Helper function to upload file to Firebase Storage
async function uploadFileToStorage(localFilePath, storagePath, bucket) {
  try {
    console.log(`📤 Uploading: ${path.basename(localFilePath)} → ${storagePath}`);
    
    // Upload file
    const [file] = await bucket.upload(localFilePath, {
      destination: storagePath,
      metadata: {
        metadata: {
          uploadedAt: new Date().toISOString(),
          source: 'adalo_migration'
        }
      }
    });
    
    // Make file publicly accessible
    await file.makePublic();
    
    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    console.log(`✅ Uploaded: ${publicUrl}`);
    
    return publicUrl;
    
  } catch (error) {
    console.error(`❌ Upload failed for ${localFilePath}:`, error.message);
    throw error;
  }
}

// Helper function to create complete Firestore document with image
async function createFirestoreDocument(collectionName, recordInfo, imageUrl, imageField) {
  try {
    // Use original Adalo ID as document ID for easy reference
    const docRef = db.collection(collectionName).doc(recordInfo.id.toString());
    
    // Prepare the complete document data
    const documentData = {
      // Original Adalo data (cleaned up)
      ...recordInfo,
      
      // Add Firebase image URL
      [imageField]: imageUrl,
      firebaseImageUrl: imageUrl, // Also store with consistent name
      
      // Metadata
      adaloId: recordInfo.id,
      collectionType: recordInfo.collectionType,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
      imageSource: 'firebase_storage',
      
      // Remove the downloadedAt field (migration-specific)
      downloadedAt: admin.firestore.FieldValue.delete(),
      
      // Convert Adalo timestamps to Firestore timestamps
      createdAt: recordInfo.created_at ? admin.firestore.Timestamp.fromDate(new Date(recordInfo.created_at)) : null,
      updatedAt: recordInfo.updated_at ? admin.firestore.Timestamp.fromDate(new Date(recordInfo.updated_at)) : null
    };
    
    // Remove undefined/null fields to keep documents clean
    Object.keys(documentData).forEach(key => {
      if (documentData[key] === undefined || documentData[key] === null) {
        delete documentData[key];
      }
    });
    
    // Create or update the document
    await docRef.set(documentData, { merge: true });
    
    console.log(`✅ Created Firestore document: ${collectionName}/${recordInfo.id}`);
    return true;
    
  } catch (error) {
    console.error(`❌ Firestore creation failed for ${collectionName}/${recordInfo.id}:`, error.message);
    return false;
  }
}

// Main function to process a collection
async function processCollection(collectionKey, config, bucket) {
  console.log(`\n🚀 Processing ${collectionKey.toUpperCase()} collection...`);
  
  const localCollectionDir = path.join(CONFIG.localImagesDir, config.localDir);
  
  if (!fs.existsSync(localCollectionDir)) {
    console.log(`⚠️  Directory not found: ${localCollectionDir}`);
    return {
      collectionKey,
      totalProcessed: 0,
      successfulUploads: 0,
      failedUploads: 0,
      firestoreUpdates: 0
    };
  }
  
  const recordDirs = fs.readdirSync(localCollectionDir, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory())
    .map(dirent => dirent.name);
  
  console.log(`📁 Found ${recordDirs.length} records with potential images`);
  
  let totalProcessed = 0;
  let successfulUploads = 0;
  let failedUploads = 0;
  let firestoreUpdates = 0;
  
  for (const recordDir of recordDirs) {
    const recordPath = path.join(localCollectionDir, recordDir);
    const recordInfoPath = path.join(recordPath, 'record_info.json');
    
    console.log(`\n📂 Processing ${recordDir}...`);
    totalProcessed++;
    
    // Read record info
    let recordInfo;
    try {
      recordInfo = JSON.parse(fs.readFileSync(recordInfoPath, 'utf8'));
    } catch (error) {
      console.error(`❌ Could not read record info: ${error.message}`);
      failedUploads++;
      continue;
    }
    
    // Find image files in the directory
    const files = fs.readdirSync(recordPath);
    const imageFiles = files.filter(file => {
      const ext = path.extname(file).toLowerCase();
      return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext);
    });
    
    if (imageFiles.length === 0) {
      console.log(`⚠️  No image files found`);
      continue;
    }
    
    // Process the first image file (assuming one image per record)
    const imageFile = imageFiles[0];
    const localImagePath = path.join(recordPath, imageFile);
    
    try {
      // Generate storage path
      const fileExtension = path.extname(imageFile);
      const fileName = `${recordInfo.id}_${Date.now()}${fileExtension}`;
      const storagePath = `${config.storagePrefix}${fileName}`;
      
                    // Upload to Firebase Storage
       const publicUrl = await uploadFileToStorage(localImagePath, storagePath, bucket);
       successfulUploads++;
       
       // Create complete Firestore document with all data + image URL
       const firestoreSuccess = await createFirestoreDocument(
         config.firestoreCollection,
         recordInfo,
         publicUrl,
         config.imageField
       );
       
       if (firestoreSuccess) {
         firestoreUpdates++;
       }
      
    } catch (error) {
      console.error(`❌ Failed to process ${recordDir}:`, error.message);
      failedUploads++;
    }
    
    // Small delay to avoid overwhelming Firebase
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  
  return {
    collectionKey,
    totalProcessed,
    successfulUploads,
    failedUploads,
    firestoreUpdates
  };
}

// Main upload function
async function uploadAllToFirebase() {
  console.log('🚀 Starting comprehensive upload to Firebase Storage...\n');
  
  // Find working bucket first
  console.log('🔍 Finding working Storage bucket...');
  
  const bucketNames = [
    'shift-12948.firebasestorage.app', // New Firebase Storage format
    'shift-12948.appspot.com',         // Legacy format
    'shift-12948.firebaseapp.com',     // Alternative
    'shift-12948'                      // Basic format
  ];
  
  let workingBucket = null;
  
  for (const bucketName of bucketNames) {
    try {
      console.log(`   Testing bucket: ${bucketName}`);
      const testBucket = admin.storage().bucket(bucketName);
      const testFile = testBucket.file('upload-test.txt');
      await testFile.save('test upload');
      
      console.log(`✅ Found working bucket: ${bucketName}`);
      workingBucket = testBucket;
      
      // Clean up test file
      await testFile.delete();
      break;
      
    } catch (bucketError) {
      console.log(`   ❌ ${bucketName}: ${bucketError.message.includes('does not exist') ? 'Not found' : 'Error'}`);
    }
  }
  
  if (!workingBucket) {
    console.error('❌ No working Storage bucket found!');
    console.log('\n📝 SETUP REQUIRED:');
    console.log('1. Go to https://console.firebase.google.com/project/shift-12948/storage');
    console.log('2. Click "Get Started"');
    console.log('3. Choose "Start in test mode"');
    console.log('4. Select location (us-central1 recommended)');
    console.log('5. Click "Done"');
    console.log('\nThen run this script again!');
    return;
  }
  
  const results = {
    timestamp: new Date().toISOString(),
    collections: {},
    totals: {
      totalProcessed: 0,
      totalUploaded: 0,
      totalFailed: 0,
      totalFirestoreUpdates: 0
    }
  };
  
  // Process each collection
  for (const [collectionKey, config] of Object.entries(CONFIG.collections)) {
    try {
      const result = await processCollection(collectionKey, config, workingBucket);
      results.collections[collectionKey] = result;
      
      // Update totals
      results.totals.totalProcessed += result.totalProcessed;
      results.totals.totalUploaded += result.successfulUploads;
      results.totals.totalFailed += result.failedUploads;
      results.totals.totalFirestoreUpdates += result.firestoreUpdates;
      
    } catch (error) {
      console.error(`❌ Failed to process ${collectionKey}:`, error.message);
      results.collections[collectionKey] = {
        error: error.message
      };
    }
    
    // Delay between collections
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  
  // Save upload summary
  const summaryPath = path.join(CONFIG.localImagesDir, 'firebase_upload_summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(results, null, 2));
  
  // Print final summary
  console.log('\n' + '='.repeat(60));
  console.log('🎉 FIREBASE UPLOAD COMPLETED!');
  console.log('='.repeat(60));
  
  console.log(`\n📊 OVERALL RESULTS:`);
  console.log(`   📋 Records Processed: ${results.totals.totalProcessed}`);
  console.log(`   ✅ Images Uploaded: ${results.totals.totalUploaded}`);
  console.log(`   ❌ Upload Failures: ${results.totals.totalFailed}`);
  console.log(`   🔄 Firestore Updates: ${results.totals.totalFirestoreUpdates}`);
  
  const successRate = results.totals.totalProcessed > 0 
    ? ((results.totals.totalUploaded / results.totals.totalProcessed) * 100).toFixed(1)
    : 0;
  console.log(`   📈 Success Rate: ${successRate}%`);
  
  console.log(`\n📂 COLLECTION BREAKDOWN:`);
  Object.entries(results.collections).forEach(([key, data]) => {
    if (data.error) {
      console.log(`\n❌ ${key.toUpperCase()}: ERROR - ${data.error}`);
    } else {
      console.log(`\n👥 ${key.toUpperCase()}:`);
      console.log(`   📋 Processed: ${data.totalProcessed}`);
      console.log(`   ✅ Uploaded: ${data.successfulUploads}`);
      console.log(`   ❌ Failed: ${data.failedUploads}`);
      console.log(`   🔄 Firestore Updates: ${data.firestoreUpdates}`);
    }
  });
  
  console.log(`\n📋 Summary saved to: ${path.resolve(summaryPath)}`);
  
  if (results.totals.totalUploaded > 0) {
    console.log(`\n🎯 NEXT STEPS:`);
    console.log(`   1. Verify images in Firebase Console: https://console.firebase.google.com/project/shift-12948/storage`);
    console.log(`   2. Check Firestore documents have updated imageUrl fields`);
    console.log(`   3. Update your Swift app to use the new Firebase URLs`);
    console.log(`   4. Test image loading in your app`);
  }
  
  return results;
}

// Quick test function
async function testFirebaseConnection() {
  console.log('🔍 Testing Firebase connection...\n');
  
  try {
    // Test Firestore
    console.log('📊 Testing Firestore...');
    const testDoc = await db.collection('test').doc('connection').get();
    console.log('✅ Firestore connection successful');
    
    // Test Storage with multiple bucket name possibilities
    console.log('📦 Testing Storage bucket names...');
    
      const bucketNames = [
    'shift-12948.firebasestorage.app', // New Firebase Storage format
    'shift-12948.appspot.com',         // Legacy format
    'shift-12948.firebaseapp.com',     // Alternative
    'shift-12948'                      // Basic format
  ];
    
    let workingBucket = null;
    
    for (const bucketName of bucketNames) {
      try {
        console.log(`   Trying bucket: ${bucketName}`);
        const testBucket = admin.storage().bucket(bucketName);
        const testFile = testBucket.file('test-connection.txt');
        await testFile.save('test connection');
        
        console.log(`✅ Storage connection successful with: ${bucketName}`);
        workingBucket = bucketName;
        
        // Clean up test file
        await testFile.delete();
        console.log('🧹 Cleaned up test file');
        break;
        
      } catch (bucketError) {
        console.log(`   ❌ ${bucketName}: ${bucketError.message.includes('does not exist') ? 'Not found' : bucketError.message}`);
      }
    }
    
    if (workingBucket) {
      console.log(`\n🎉 Firebase Storage is ready!`);
      console.log(`📁 Working bucket: ${workingBucket}`);
      console.log('\n🚀 Ready to upload 776 images!');
    } else {
      console.log('\n❌ No working bucket found');
      console.log('\n📝 FINAL STEP - CREATE STORAGE BUCKET:');
      console.log('1. Open: https://console.firebase.google.com/project/shift-12948/storage');
      console.log('2. Click "Get Started" button');
      console.log('3. Choose "Start in test mode"');
      console.log('4. Select "us-central1" location');
      console.log('5. Click "Done"');
      console.log('\nThis creates the bucket. Then run: npm run upload-to-firebase');
    }
    
  } catch (error) {
    console.error('\n❌ Firebase Storage test failed:');
    console.error('Error:', error.message);
    
    console.log('\n📝 SETUP REQUIRED:');
    console.log('1. Open: https://console.firebase.google.com/project/shift-12948/storage');
    console.log('2. Click "Get Started" if available');
    console.log('3. Choose "Start in test mode"');
    console.log('4. Select "us-central1" location');
    console.log('5. Click "Done"');
  }
}

// Export functions
module.exports = {
  uploadAllToFirebase,
  testFirebaseConnection,
  processCollection,
  uploadFileToStorage,
  createFirestoreDocument
};

// Run based on command line argument
if (require.main === module) {
  const arg = process.argv[2];
  
  if (arg === 'test') {
    testFirebaseConnection().catch(console.error);
  } else {
    uploadAllToFirebase().catch(console.error);
  }
} 