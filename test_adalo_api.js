require('dotenv').config();
const https = require('https');

// Adalo API configuration
const ADALO_CONFIG = {
  baseUrl: `https://api.adalo.com/v0/apps/${process.env.ADALO_APP_ID}`,
  authToken: `Bearer ${process.env.ADALO_API_KEY}`,
  collections: {
    users: 't_922b75d1c0b749eca8271685ae718d82'
  }
};

// Function to fetch users from Adalo API
async function testAdaloAPI() {
  return new Promise((resolve, reject) => {
    const url = `${ADALO_CONFIG.baseUrl}/collections/${ADALO_CONFIG.collections.users}?limit=5`;
    
    const options = {
      headers: {
        'Authorization': ADALO_CONFIG.authToken,
        'Content-Type': 'application/json'
      }
    };
    
    console.log('🔍 Testing Adalo API access...');
    console.log(`📡 URL: ${url}`);
    
    https.get(url, options, (response) => {
      let data = '';
      
      response.on('data', (chunk) => {
        data += chunk;
      });
      
      response.on('end', () => {
        try {
          const jsonData = JSON.parse(data);
          
          console.log('\n✅ API Response received!');
          console.log(`📊 Status: ${response.statusCode}`);
          
          const users = jsonData.records || jsonData;
          if (users && users.length > 0) {
            console.log(`\n👥 Found ${users.length} users:`);
            
            users.forEach((user, index) => {
              console.log(`\n${index + 1}. ${user['First Name'] || 'Unknown'} (${user.Email})`);
              if (user.Photo && user.Photo.url) {
                console.log(`   📸 Photo: ${user.Photo.url}`);
                console.log(`   📁 Filename: ${user.Photo.filename}`);
                console.log(`   📏 Size: ${user.Photo.size} bytes`);
              } else {
                console.log(`   ⚠️  No photo available`);
              }
            });
          } else {
            console.log('⚠️  No users found in response');
          }
          
          resolve(jsonData);
        } catch (error) {
          console.error('❌ Failed to parse API response:', error.message);
          console.log('Raw response:', data);
          reject(error);
        }
      });
    }).on('error', (error) => {
      console.error('❌ API request failed:', error.message);
      reject(error);
    });
  });
}

// Test a direct image URL
async function testImageAccess(imageUrl) {
  return new Promise((resolve, reject) => {
    console.log(`\n🔍 Testing image access: ${imageUrl}`);
    
    https.get(imageUrl, (response) => {
      console.log(`📊 Status: ${response.statusCode}`);
      console.log(`📄 Content-Type: ${response.headers['content-type']}`);
      console.log(`📏 Content-Length: ${response.headers['content-length']}`);
      
      if (response.statusCode === 200) {
        console.log('✅ Image is accessible!');
        resolve(true);
      } else {
        console.log('❌ Image not accessible');
        resolve(false);
      }
      
      // Don't download the image, just test access
      response.destroy();
    }).on('error', (error) => {
      console.error('❌ Image access failed:', error.message);
      resolve(false);
    });
  });
}

// Main test function
async function runTests() {
  try {
    console.log('🚀 Starting Adalo API tests...\n');
    
    // Test API access
    const apiResponse = await testAdaloAPI();
    
    // Test image access for first user with photo
    const users = apiResponse.records || apiResponse;
    if (users && users.length > 0) {
      const userWithPhoto = users.find(user => user.Photo && user.Photo.url);
      if (userWithPhoto) {
        await testImageAccess(userWithPhoto.Photo.url);
      } else {
        console.log('\n⚠️  No users with photos found in the test batch');
      }
    }
    
    console.log('\n🎉 API tests completed!');
    
  } catch (error) {
    console.error('\n💥 Test failed:', error.message);
  }
}

// Run the tests
if (require.main === module) {
  runTests();
}

module.exports = { testAdaloAPI, testImageAccess }; 