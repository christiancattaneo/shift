require('dotenv').config();
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

// Adalo API configuration
const ADALO_CONFIG = {
  baseUrl: `https://api.adalo.com/v0/apps/${process.env.ADALO_APP_ID}`,
  authToken: `Bearer ${process.env.ADALO_API_KEY}`,
  collections: {
    users: 't_922b75d1c0b749eca8271685ae718d82'
  }
};

// Create organized directory structure
const baseDir = './downloaded_images';
const usersDir = path.join(baseDir, 'users');

function createDirectories() {
  if (!fs.existsSync(baseDir)) fs.mkdirSync(baseDir, { recursive: true });
  if (!fs.existsSync(usersDir)) fs.mkdirSync(usersDir, { recursive: true });
}

// Helper function to sanitize filename for filesystem
function sanitizeFilename(filename) {
  return filename.replace(/[<>:"/\\|?*]/g, '_').replace(/\s+/g, '_');
}

// Helper function to download image from URL
async function downloadImage(imageUrl, filePath) {
  return new Promise((resolve, reject) => {
    try {
      const parsedUrl = new URL(imageUrl);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;
      
      console.log(`📥 Downloading: ${path.basename(filePath)}`);
      
      const request = protocol.get(imageUrl, (response) => {
        if (response.statusCode === 200) {
          const fileStream = fs.createWriteStream(filePath);
          
          response.pipe(fileStream);
          
          fileStream.on('finish', () => {
            fileStream.close();
            console.log(`✅ Downloaded: ${path.basename(filePath)}`);
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

// Function to save user info to JSON
function saveUserInfo(userDir, user) {
  const userInfo = {
    id: user.id,
    email: user.Email,
    firstName: user['First Name'],
    gender: user.Gender,
    age: user.Age,
    city: user.City,
    attractedTo: user['Attracted to'],
    howToApproachMe: user['How to Approach Me'],
    instagramHandle: user['Instagram Handle'],
    photo: user.Photo ? {
      originalUrl: user.Photo.url,
      filename: user.Photo.filename,
      size: user.Photo.size,
      width: user.Photo.width,
      height: user.Photo.height
    } : null,
    createdAt: user.created_at,
    updatedAt: user.updated_at
  };
  
  const infoPath = path.join(userDir, 'user_info.json');
  fs.writeFileSync(infoPath, JSON.stringify(userInfo, null, 2));
}

// Main function to download all user images
async function downloadAllImages() {
  console.log('🚀 Starting local image download from Adalo...\n');
  
  createDirectories();
  
  let offset = 0;
  const limit = 100;
  let totalProcessed = 0;
  let successCount = 0;
  let errorCount = 0;
  let noImageCount = 0;
  
  const downloadSummary = [];
  
  try {
    while (true) {
      const response = await fetchAdaloUsers(limit, offset);
      const users = response.records || response;
      
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
        
        // Create user directory
        const sanitizedEmail = sanitizeFilename(email);
        const userDir = path.join(usersDir, `${totalProcessed}_${sanitizedEmail}`);
        if (!fs.existsSync(userDir)) fs.mkdirSync(userDir, { recursive: true });
        
        // Save user info
        saveUserInfo(userDir, user);
        
        if (!photo || !photo.url) {
          console.log(`⚠️  No photo URL for user: ${email}`);
          noImageCount++;
          downloadSummary.push({
            user: email,
            status: 'no_image',
            message: 'No photo available'
          });
          continue;
        }
        
        try {
          const imageUrl = photo.url;
          const originalFilename = photo.filename || 'profile_image';
          const fileExtension = path.extname(originalFilename) || '.jpg';
          const fileName = `profile_${sanitizeFilename(originalFilename)}`;
          
          console.log(`📸 Image URL: ${imageUrl}`);
          console.log(`📁 Original filename: ${originalFilename}`);
          
          // Download image
          const localPath = path.join(userDir, fileName);
          await downloadImage(imageUrl, localPath);
          
          successCount++;
          downloadSummary.push({
            user: email,
            status: 'success',
            localPath: localPath,
            originalUrl: imageUrl,
            filename: fileName
          });
          
        } catch (error) {
          console.error(`❌ Error downloading image for ${email}:`, error.message);
          errorCount++;
          downloadSummary.push({
            user: email,
            status: 'error',
            message: error.message,
            originalUrl: photo.url
          });
        }
      }
      
      offset += limit;
      
      // Add a small delay to be respectful to the API
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
  } catch (error) {
    console.error('💥 Fatal error in main process:', error);
  }
  
  // Save download summary
  const summaryPath = path.join(baseDir, 'download_summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify({
    timestamp: new Date().toISOString(),
    totals: {
      processed: totalProcessed,
      successful: successCount,
      errors: errorCount,
      noImages: noImageCount
    },
    downloads: downloadSummary
  }, null, 2));
  
  // Final summary
  console.log('\n🎉 Local image download completed!');
  console.log('📊 Final Results:');
  console.log(`   👥 Total users processed: ${totalProcessed}`);
  console.log(`   ✅ Successfully downloaded: ${successCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log(`   ⚠️  No images: ${noImageCount}`);
  console.log(`\n📁 Images saved to: ${path.resolve(baseDir)}`);
  console.log(`📋 Summary saved to: ${path.resolve(summaryPath)}`);
  
  // Instructions for next steps
  console.log('\n📝 Next Steps:');
  console.log('1. Enable Firebase Storage in your Firebase Console');
  console.log('2. Run: npm run setup-firebase-storage');
  console.log('3. Then run: npm run upload-local-images');
}

// Run the script
if (require.main === module) {
  downloadAllImages().catch(console.error);
}

module.exports = {
  downloadAllImages,
  fetchAdaloUsers,
  downloadImage
}; 