require('dotenv').config();
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'shift-12948'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Adalo API configuration
const ADALO_CONFIG = {
  baseUrl: `https://api.adalo.com/v0/apps/${process.env.ADALO_APP_ID}`,
  authToken: `Bearer ${process.env.ADALO_API_KEY}`,
  collections: {
    users: 't_922b75d1c0b749eca8271685ae718d82'
    // Add events and places collection IDs here if needed
  }
};

// Create temp directory for downloaded images
const tempDir = './temp_images_api';
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

// Helper function to download image from URL
async function downloadImage(imageUrl, filename) {
  return new Promise((resolve, reject) => {
    try {
      const parsedUrl = new URL(imageUrl);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;
      
      console.log(`📥 Downloading: ${imageUrl}`);
      
      const request = protocol.get(imageUrl, (response) => {
        if (response.statusCode === 200) {
          const filePath = path.join(tempDir, filename);
          const fileStream = fs.createWriteStream(filePath);
          
          response.pipe(fileStream);
          
          fileStream.on('finish', () => {
            fileStream.close();
            console.log(`✅ Downloaded: ${filename}`);
            resolve(filePath);
          });
          
          fileStream.on('error', (error) => {
            fs.unlink(filePath, () => {}); // Clean up partial file
            reject(error);
          });
        } else {
          reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
        }
      });
      
      request.on('error', reject);
      request.setTimeout(30000, () => {
        request.destroy();
        reject(new Error('Download timeout'));
      });
    } catch (error) {
      reject(error);
    }
  });
}

// Helper function to upload image to Firebase Storage
async function uploadToFirebase(localPath, fileName, userEmail) {
  try {
    console.log(`📤 Uploading to Firebase: ${fileName}`);
    
    // Create a sanitized path for Firebase Storage
    const sanitizedEmail = userEmail.replace(/[^a-zA-Z0-9]/g, '_');
    const storagePath = `user_images/${sanitizedEmail}/${fileName}`;
    
    const [file] = await bucket.upload(localPath, {
      destination: storagePath,
      metadata: {
        metadata: {
          originalEmail: userEmail,
          uploadedAt: new Date().toISOString()
        }
      }
    });
    
    // Make the file publicly accessible
    await file.makePublic();
    
    // Get the public URL
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-09-2491' // Far future date for permanent access
    });
    
    // Or use the public URL format
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
    console.log(`✅ Uploaded to Firebase: ${publicUrl}`);
    
    return publicUrl;
  } catch (error) {
    console.error(`❌ Firebase upload failed for ${fileName}:`, error.message);
    throw error;
  }
}

// Function to fetch users from Adalo API
async function fetchAdaloUsers(limit = 100, offset = 0) {
  return new Promise((resolve, reject) => {
    const url = `${ADALO_CONFIG.baseUrl}/collections/${ADALO_CONFIG.collections.users}?limit=${limit}&offset=${offset}`;
    
    const options = {
      headers: {
        'Authorization': ADALO_CONFIG.authToken,
        'Content-Type': 'application/json'
      }
    };
    
    console.log(`🔍 Fetching users from Adalo API (limit: ${limit}, offset: ${offset})`);
    
    https.get(url, options, (response) => {
      let data = '';
      
      response.on('data', (chunk) => {
        data += chunk;
      });
      
      response.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          resolve(jsonData);
        } catch (error) {
          reject(new Error(`Failed to parse API response: ${error.message}`));
        }
      });
    }).on('error', reject);
  });
}

// Function to update Firestore user with new image URL
async function updateUserInFirestore(userEmail, newImageUrl) {
  try {
    const usersRef = db.collection('users');
    const querySnapshot = await usersRef.where('email', '==', userEmail).get();
    
    if (querySnapshot.empty) {
      console.log(`⚠️  No Firestore user found for email: ${userEmail}`);
      return false;
    }
    
    const promises = querySnapshot.docs.map(doc => {
      return doc.ref.update({
        photo: newImageUrl,
        photoUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await Promise.all(promises);
    console.log(`✅ Updated Firestore user: ${userEmail}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to update Firestore user ${userEmail}:`, error.message);
    return false;
  }
}

// Main function to process user images
async function processUserImages() {
  console.log('🚀 Starting Adalo image download and Firebase upload process...\n');
  
  let offset = 0;
  const limit = 100;
  let totalProcessed = 0;
  let successCount = 0;
  let errorCount = 0;
  let noImageCount = 0;
  
  try {
    while (true) {
      const response = await fetchAdaloUsers(limit, offset);
      const users = response.records || response; // Handle different response formats
      
      if (!users || users.length === 0) {
        console.log('📋 No more users to process');
        break;
      }
      
      console.log(`\n📊 Processing batch: ${users.length} users (offset: ${offset})`);
      
      for (const user of users) {
        totalProcessed++;
        const email = user.Email;
        const firstName = user['First Name'] || 'Unknown';
        const photo = user.Photo;
        
        console.log(`\n👤 Processing user ${totalProcessed}: ${firstName} (${email})`);
        
        if (!photo || !photo.url) {
          console.log(`⚠️  No photo URL for user: ${email}`);
          noImageCount++;
          continue;
        }
        
        try {
          const imageUrl = photo.url;
          const originalFilename = photo.filename || 'profile_image';
          const fileExtension = path.extname(originalFilename) || '.jpg';
          const fileName = `${Date.now()}_${originalFilename}`;
          
          console.log(`📸 Image URL: ${imageUrl}`);
          console.log(`📁 Original filename: ${originalFilename}`);
          
          // Download image from Adalo
          const localPath = await downloadImage(imageUrl, fileName);
          
          // Upload to Firebase Storage
          const firebaseUrl = await uploadToFirebase(localPath, fileName, email);
          
          // Update user in Firestore
          const updated = await updateUserInFirestore(email, firebaseUrl);
          
          if (updated) {
            successCount++;
          }
          
          // Clean up local file
          fs.unlink(localPath, (err) => {
            if (err) console.log(`⚠️  Could not delete local file: ${localPath}`);
          });
          
        } catch (error) {
          console.error(`❌ Error processing user ${email}:`, error.message);
          errorCount++;
        }
      }
      
      offset += limit;
      
      // Add a small delay to be respectful to the API
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
  } catch (error) {
    console.error('💥 Fatal error in main process:', error);
  }
  
  // Final summary
  console.log('\n🎉 Image processing completed!');
  console.log('📊 Final Results:');
  console.log(`   👥 Total users processed: ${totalProcessed}`);
  console.log(`   ✅ Successfully uploaded: ${successCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log(`   ⚠️  No images: ${noImageCount}`);
  
  // Clean up temp directory
  try {
    fs.rmSync(tempDir, { recursive: true, force: true });
    console.log('🧹 Temporary files cleaned up');
  } catch (error) {
    console.log('⚠️  Could not clean up temporary directory:', error.message);
  }
}

// Run the script
if (require.main === module) {
  processUserImages().catch(console.error);
}

module.exports = {
  processUserImages,
  fetchAdaloUsers,
  downloadImage,
  uploadToFirebase
}; 