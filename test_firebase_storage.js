const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'shift-12948'
});

async function testFirebaseStorage() {
  console.log('🔍 Testing Firebase Storage access...\n');
  
  // Test default bucket access
  console.log('📦 Testing default bucket...');
  try {
    const defaultBucket = admin.storage().bucket();
    console.log(`Default bucket name: ${defaultBucket.name}`);
    
    // Test if we can list files (this will tell us if the bucket exists)
    const [files] = await defaultBucket.getFiles({ maxResults: 1 });
    console.log(`✅ Default bucket exists and is accessible`);
    console.log(`📁 Found ${files.length} files in first page`);
  } catch (error) {
    console.log(`❌ Default bucket error: ${error.message}`);
  }
  
  // Try common bucket name variations
  const bucketVariations = [
    'shift-12948.appspot.com',
    'shift-12948.firebaseapp.com',
    'shift-12948',
    'shift-12948-default-rtdb'
  ];
  
  console.log('\n📦 Testing bucket name variations...');
  for (const bucketName of bucketVariations) {
    try {
      console.log(`\nTesting: ${bucketName}`);
      const testBucket = admin.storage().bucket(bucketName);
      const [files] = await testBucket.getFiles({ maxResults: 1 });
      console.log(`✅ Bucket "${bucketName}" exists and is accessible`);
    } catch (error) {
      console.log(`❌ Bucket "${bucketName}": ${error.message}`);
    }
  }
  
  // Test creating a simple file to see what happens
  console.log('\n📝 Testing file upload...');
  try {
    const testBucket = admin.storage().bucket('shift-12948.appspot.com');
    const file = testBucket.file('test/test.txt');
    
    await file.save('Hello Firebase Storage!', {
      metadata: {
        contentType: 'text/plain'
      }
    });
    
    console.log('✅ Successfully uploaded test file');
    
    // Clean up test file
    await file.delete();
    console.log('🧹 Test file cleaned up');
    
  } catch (error) {
    console.log(`❌ Upload test failed: ${error.message}`);
  }
}

// Run the test
if (require.main === module) {
  testFirebaseStorage().then(() => {
    console.log('\n🎉 Firebase Storage test completed!');
  }).catch(console.error);
}

module.exports = { testFirebaseStorage }; 