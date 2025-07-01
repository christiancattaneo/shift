const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Your Adalo API Configuration
const ADALO_CONFIG = {
  appId: 'a03b07ee-0cee-4d06-82bb-75e4f6193332',
  collectionId: 't_922b75d1c0b749eca8271685ae718d82',
  apiKey: 'e5tvtd15e7hsiipspcv5fhf67',
  baseUrl: 'https://api.adalo.com/v0'
};

// Create directories for data storage
const DATA_DIR = './adalo_data';
const USERS_DIR = path.join(DATA_DIR, 'users');
const IMAGES_DIR = path.join(DATA_DIR, 'images');

if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR);
if (!fs.existsSync(USERS_DIR)) fs.mkdirSync(USERS_DIR);
if (!fs.existsSync(IMAGES_DIR)) fs.mkdirSync(IMAGES_DIR);

// Download function for images
function downloadImage(url, filename) {
  return new Promise((resolve, reject) => {
    if (!url) {
      console.log(`❌ No image URL for ${filename}`);
      return resolve(null);
    }

    const protocol = url.startsWith('https') ? https : http;
    const filePath = path.join(IMAGES_DIR, filename);

    console.log(`📸 Downloading image: ${filename} from ${url}`);

    const file = fs.createWriteStream(filePath);
    
    protocol.get(url, (response) => {
      if (response.statusCode !== 200) {
        console.log(`❌ Failed to download ${filename}: HTTP ${response.statusCode}`);
        return resolve(null);
      }

      response.pipe(file);
      
      file.on('finish', () => {
        file.close();
        console.log(`✅ Downloaded: ${filename}`);
        resolve(filePath);
      });
    }).on('error', (err) => {
      fs.unlink(filePath, () => {}); // Delete partial file
      console.log(`❌ Error downloading ${filename}: ${err.message}`);
      resolve(null);
    });
  });
}

// Fetch users from Adalo API
async function fetchAdaloUsers() {
  console.log('🚀 Starting Adalo user download...');
  
  const allUsers = [];
  let offset = 0;
  const limit = 1000; // Max per Adalo API
  let hasMore = true;

  while (hasMore) {
    const url = `${ADALO_CONFIG.baseUrl}/apps/${ADALO_CONFIG.appId}/collections/${ADALO_CONFIG.collectionId}?offset=${offset}&limit=${limit}`;
    
    console.log(`📡 Fetching users: offset=${offset}, limit=${limit}`);

    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${ADALO_CONFIG.apiKey}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`Adalo API error: ${response.status} ${response.statusText}`);
      }

      const data = await response.json();
      
      console.log(`✅ Fetched ${data.records.length} users (total so far: ${allUsers.length + data.records.length})`);
      
      allUsers.push(...data.records);
      
      hasMore = data.records.length === limit;
      offset += limit;

    } catch (error) {
      console.error(`❌ Error fetching users:`, error.message);
      break;
    }
  }

  console.log(`🎉 Total users fetched: ${allUsers.length}`);
  return allUsers;
}

// Main execution function
async function main() {
  try {
    console.log('🔗 Downloading all users and images from Adalo...');
    console.log(`📋 App ID: ${ADALO_CONFIG.appId}`);
    console.log(`📋 Collection ID: ${ADALO_CONFIG.collectionId}`);
    
    // Step 1: Download all user data
    const users = await fetchAdaloUsers();
    
    if (users.length === 0) {
      console.log('❌ No users found. Check your API configuration.');
      return;
    }

    // Save raw user data
    const usersJsonPath = path.join(DATA_DIR, 'all_users.json');
    fs.writeFileSync(usersJsonPath, JSON.stringify(users, null, 2));
    console.log(`💾 Saved raw user data to: ${usersJsonPath}`);

    // Step 2: Download profile images
    console.log('\n📸 Starting image downloads...');
    
    const downloadResults = {
      total: users.length,
      withImages: 0,
      downloaded: 0,
      failed: 0,
      errors: []
    };

    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      const firstName = user['First Name'] || user.firstName || 'Unknown';
      const userId = user.id;
      
      console.log(`\n[${i + 1}/${users.length}] Processing: ${firstName} (ID: ${userId})`);

      // Look for profile photo in different possible fields
      let imageUrl = null;
      let imageField = null;

      // Check all possible image field names
      const imageFields = [
        'Profile Photo',
        'profilePhoto', 
        'profile_photo',
        'Image',
        'image',
        'Photo',
        'photo'
      ];

      for (const field of imageFields) {
        if (user[field]) {
          if (typeof user[field] === 'string') {
            imageUrl = user[field];
            imageField = field;
            break;
          } else if (user[field].url) {
            imageUrl = user[field].url;
            imageField = field;
            break;
          }
        }
      }

      if (imageUrl) {
        downloadResults.withImages++;
        
        // Create filename: userId_firstName.jpg
        const sanitizedName = firstName.replace(/[^a-zA-Z0-9]/g, '_');
        const filename = `${userId}_${sanitizedName}.jpg`;
        
        console.log(`📸 Found image in field '${imageField}': ${imageUrl}`);
        
        const downloadPath = await downloadImage(imageUrl, filename);
        
        if (downloadPath) {
          downloadResults.downloaded++;
          // Add download info to user object
          user._downloadedImage = {
            originalUrl: imageUrl,
            localPath: downloadPath,
            filename: filename,
            sourceField: imageField
          };
        } else {
          downloadResults.failed++;
          downloadResults.errors.push({
            userId,
            firstName,
            imageUrl,
            error: 'Download failed'
          });
        }
      } else {
        console.log(`❌ No image found for ${firstName}`);
      }

      // Save individual user file
      const userFilePath = path.join(USERS_DIR, `user_${userId}.json`);
      fs.writeFileSync(userFilePath, JSON.stringify(user, null, 2));
    }

    // Step 3: Generate summary
    console.log('\n🎉 Download Complete!');
    console.log('📊 Summary:');
    console.log(`   Total Users: ${downloadResults.total}`);
    console.log(`   Users with Images: ${downloadResults.withImages}`);
    console.log(`   Images Downloaded: ${downloadResults.downloaded}`);
    console.log(`   Download Failures: ${downloadResults.failed}`);

    // Save updated user data with download info
    const updatedUsersPath = path.join(DATA_DIR, 'users_with_images.json');
    fs.writeFileSync(updatedUsersPath, JSON.stringify(users, null, 2));
    
    // Save download summary
    const summaryPath = path.join(DATA_DIR, 'download_summary.json');
    fs.writeFileSync(summaryPath, JSON.stringify(downloadResults, null, 2));

    console.log(`\n💾 Files saved:`);
    console.log(`   Raw users: ${usersJsonPath}`);
    console.log(`   Users with images: ${updatedUsersPath}`);
    console.log(`   Individual users: ${USERS_DIR}/`);
    console.log(`   Downloaded images: ${IMAGES_DIR}/`);
    console.log(`   Summary: ${summaryPath}`);

    if (downloadResults.errors.length > 0) {
      console.log(`\n⚠️  Errors occurred for ${downloadResults.errors.length} users`);
      downloadResults.errors.forEach(err => {
        console.log(`   ${err.firstName} (${err.userId}): ${err.error}`);
      });
    }

  } catch (error) {
    console.error('❌ Fatal error:', error);
  }
}

// Handle fetch for Node.js (if not available globally)
if (typeof fetch === 'undefined') {
  global.fetch = require('node-fetch');
}

// Run the script
main().catch(console.error); 