const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

// Initialize Firebase Admin SDK
admin.initializeApp({
  projectId: 'shift-12948',
  storageBucket: 'shift-12948.appspot.com'
});

const db = admin.firestore();
const bucket = admin.storage().bucket('shift-12948.appspot.com');

// Create directories for downloaded images
const tempDir = './temp_images';
if (!fs.existsSync(tempDir)) {
  fs.mkdirSync(tempDir, { recursive: true });
}

// Helper function to download image from URL
async function downloadImage(imageUrl, filename) {
  return new Promise((resolve, reject) => {
    try {
      const parsedUrl = new URL(imageUrl);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;
      
      const localPath = path.join(tempDir, filename);
      const file = fs.createWriteStream(localPath);
      
      const request = protocol.get(imageUrl, (response) => {
        if (response.statusCode === 200) {
          response.pipe(file);
          file.on('finish', () => {
            file.close();
            console.log(`✅ Downloaded: ${filename}`);
            resolve(localPath);
          });
        } else {
          reject(new Error(`Failed to download ${imageUrl}: ${response.statusCode}`));
        }
      });
      
      request.on('error', (error) => {
        fs.unlink(localPath, () => {}); // Delete partial file
        reject(error);
      });
      
      file.on('error', (error) => {
        fs.unlink(localPath, () => {}); // Delete partial file
        reject(error);
      });
    } catch (error) {
      reject(error);
    }
  });
}

// Helper function to upload image to Firebase Storage
async function uploadToFirebase(localPath, firebasePath) {
  try {
    const [file] = await bucket.upload(localPath, {
      destination: firebasePath,
      metadata: {
        contentType: getContentType(localPath)
      }
    });
    
    // Make the file publicly accessible
    await file.makePublic();
    
    // Return the public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${firebasePath}`;
    console.log(`🔥 Uploaded to Firebase: ${firebasePath}`);
    return publicUrl;
  } catch (error) {
    console.error(`❌ Failed to upload ${localPath}:`, error.message);
    throw error;
  }
}

// Helper function to get content type from file extension
function getContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const contentTypes = {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.tiff': 'image/tiff',
    '.heic': 'image/heic'
  };
  return contentTypes[ext] || 'image/jpeg';
}

// Helper function to extract image URL from Adalo image data
function extractImageUrl(imageDataString) {
  if (!imageDataString || imageDataString.trim() === '') {
    return null;
  }
  
  try {
    // Clean up the string and parse JSON
    const cleanedString = imageDataString.replace(/'/g, '"');
    const imageData = JSON.parse(cleanedString);
    
    if (imageData.url) {
      // If it's a relative URL, make it absolute
      if (imageData.url.startsWith('http')) {
        return imageData.url;
      } else {
        // Construct Adalo URL - you may need to adjust this based on your Adalo setup
        return `https://cdn.adalo.com/uploads/${imageData.url}`;
      }
    }
  } catch (error) {
    console.log(`⚠️  Could not parse image data: ${imageDataString.substring(0, 100)}...`);
  }
  
  return null;
}

// Helper function to generate safe filename
function generateSafeFilename(originalUrl, fallbackName, id) {
  try {
    const parsedUrl = new URL(originalUrl);
    const filename = path.basename(parsedUrl.pathname);
    if (filename && filename.includes('.')) {
      return filename;
    }
  } catch (error) {
    // URL parsing failed
  }
  
  // Fallback to ID-based naming
  return `${fallbackName}_${id}.jpg`;
}

// Process Users images
async function processUserImages() {
  console.log('🔄 Processing user profile images...');
  
  const results = [];
  const usersFile = path.join(__dirname, 'data/Users.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(usersFile)
      .pipe(csv())
      .on('data', (data) => results.push(data))
      .on('end', async () => {
        let successCount = 0;
        let errorCount = 0;
        
        for (const user of results) {
          try {
            const imageUrl = extractImageUrl(user.Photo);
            if (!imageUrl) {
              console.log(`⚠️  No image URL for user ${user.Email}`);
              continue;
            }
            
            const userId = user[' ID'] || user['ID'];
            const filename = generateSafeFilename(imageUrl, 'user', userId);
            const firebasePath = `profile_images/${userId}/${filename}`;
            
            // Download image
            const localPath = await downloadImage(imageUrl, filename);
            
            // Upload to Firebase
            const firebaseUrl = await uploadToFirebase(localPath, firebasePath);
            
            // Update Firestore document
            await db.collection('users').where('email', '==', user.Email.toLowerCase()).get()
              .then(async (querySnapshot) => {
                if (!querySnapshot.empty) {
                  const userDoc = querySnapshot.docs[0];
                  await userDoc.ref.update({
                    profilePhoto: firebaseUrl,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp()
                  });
                  console.log(`📄 Updated Firestore for user: ${user.Email}`);
                }
              });
            
            // Clean up local file
            fs.unlinkSync(localPath);
            
            successCount++;
            
          } catch (error) {
            console.error(`❌ Error processing user ${user.Email}:`, error.message);
            errorCount++;
          }
        }
        
        console.log(`\n✅ User images processed: ${successCount} success, ${errorCount} errors`);
        resolve();
      })
      .on('error', reject);
  });
}

// Process Events images
async function processEventImages() {
  console.log('🔄 Processing event images...');
  
  const results = [];
  const eventsFile = path.join(__dirname, 'data/Events.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(eventsFile)
      .pipe(csv())
      .on('data', (data) => results.push(data))
      .on('end', async () => {
        let successCount = 0;
        let errorCount = 0;
        
        for (const event of results) {
          try {
            const imageUrl = extractImageUrl(event.Image);
            if (!imageUrl) {
              console.log(`⚠️  No image URL for event ${event['Event Name']}`);
              continue;
            }
            
            const eventId = event[' ID'] || event['ID'];
            const filename = generateSafeFilename(imageUrl, 'event', eventId);
            const firebasePath = `event_images/${eventId}/${filename}`;
            
            // Download image
            const localPath = await downloadImage(imageUrl, filename);
            
            // Upload to Firebase
            const firebaseUrl = await uploadToFirebase(localPath, firebasePath);
            
            // Update Firestore document
            await db.collection('events').doc(eventId.toString()).update({
              image: firebaseUrl,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`📄 Updated Firestore for event: ${event['Event Name']}`);
            
            // Clean up local file
            fs.unlinkSync(localPath);
            
            successCount++;
            
          } catch (error) {
            console.error(`❌ Error processing event ${event['Event Name']}:`, error.message);
            errorCount++;
          }
        }
        
        console.log(`\n✅ Event images processed: ${successCount} success, ${errorCount} errors`);
        resolve();
      })
      .on('error', reject);
  });
}

// Process Places images
async function processPlaceImages() {
  console.log('🔄 Processing place images...');
  
  const results = [];
  const placesFile = path.join(__dirname, 'data/Places.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(placesFile)
      .pipe(csv())
      .on('data', (data) => results.push(data))
      .on('end', async () => {
        let successCount = 0;
        let errorCount = 0;
        
        for (const place of results) {
          try {
            const imageUrl = extractImageUrl(place['Place Image']);
            if (!imageUrl) {
              console.log(`⚠️  No image URL for place ${place['Place Name']}`);
              continue;
            }
            
            const placeId = place[' ID'] || place['ID'];
            const filename = generateSafeFilename(imageUrl, 'place', placeId);
            const firebasePath = `place_images/${placeId}/${filename}`;
            
            // Download image
            const localPath = await downloadImage(imageUrl, filename);
            
            // Upload to Firebase
            const firebaseUrl = await uploadToFirebase(localPath, firebasePath);
            
            // Update Firestore document
            await db.collection('places').doc(placeId.toString()).update({
              placeImage: firebaseUrl,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`📄 Updated Firestore for place: ${place['Place Name']}`);
            
            // Clean up local file
            fs.unlinkSync(localPath);
            
            successCount++;
            
          } catch (error) {
            console.error(`❌ Error processing place ${place['Place Name']}:`, error.message);
            errorCount++;
          }
        }
        
        console.log(`\n✅ Place images processed: ${successCount} success, ${errorCount} errors`);
        resolve();
      })
      .on('error', reject);
  });
}

// Main execution
async function main() {
  try {
    console.log('🚀 Starting image download and upload process...\n');
    
    // Process all image types
    await processUserImages();
    await processEventImages();
    await processPlaceImages();
    
    console.log('\n🎉 All image processing completed!');
    console.log('📁 Temporary files have been cleaned up');
    
    // Clean up temp directory
    fs.rmSync(tempDir, { recursive: true, force: true });
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
    process.exit(1);
  }
}

// Run the script
main(); 