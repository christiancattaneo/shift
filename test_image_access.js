const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');
const config = require('./image_config');

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
      return imageData.url;
    }
  } catch (error) {
    console.log(`⚠️  Could not parse image data: ${imageDataString.substring(0, 100)}...`);
  }
  
  return null;
}

// Test function to check image URL accessibility
function testImageUrl(imageUrl) {
  return new Promise((resolve) => {
    try {
      // Try URLs from configuration file
      const urlsToTest = config.adalo.baseUrls.map(baseUrl => {
        if (baseUrl === '') {
          // Try the URL as-is
          return imageUrl.startsWith('http') ? imageUrl : null;
        }
        return `${baseUrl}${imageUrl}`;
      }).filter(url => url !== null);
      
      const testUrl = async (url) => {
        return new Promise((urlResolve) => {
          try {
            const parsedUrl = new URL(url);
            const protocol = parsedUrl.protocol === 'https:' ? https : http;
            
            const request = protocol.get(url, (response) => {
              console.log(`📍 Testing: ${url}`);
              console.log(`   Status: ${response.statusCode}`);
              console.log(`   Content-Type: ${response.headers['content-type']}`);
              console.log(`   Content-Length: ${response.headers['content-length']}`);
              
              if (response.statusCode === 200 && response.headers['content-type']?.startsWith('image/')) {
                console.log(`✅ SUCCESS: Image accessible at ${url}\n`);
                urlResolve({ success: true, url: url });
              } else {
                console.log(`❌ FAILED: ${url}\n`);
                urlResolve({ success: false, url: url });
              }
              
              response.destroy(); // Don't download the full image
            });
            
            request.on('error', (error) => {
              console.log(`❌ ERROR testing ${url}:`, error.message);
              urlResolve({ success: false, url: url, error: error.message });
            });
            
            request.setTimeout(5000, () => {
              request.destroy();
              console.log(`⏱️  TIMEOUT: ${url}\n`);
              urlResolve({ success: false, url: url, error: 'timeout' });
            });
          } catch (error) {
            console.log(`❌ PARSE ERROR for ${url}:`, error.message);
            urlResolve({ success: false, url: url, error: error.message });
          }
        });
      };
      
      // Test all URL formats sequentially
      (async () => {
        for (const url of urlsToTest) {
          const result = await testUrl(url);
          if (result.success) {
            resolve(result);
            return;
          }
        }
        resolve({ success: false, urls: urlsToTest });
      })();
      
    } catch (error) {
      resolve({ success: false, error: error.message });
    }
  });
}

// Main test function
async function testImageAccess() {
  console.log('🔍 Testing Adalo image URL accessibility...\n');
  
  // Test a few sample images from each category
  const tests = [
    { file: 'data/Users.csv', field: 'Photo', type: 'User' },
    { file: 'data/Events.csv', field: 'Image', type: 'Event' },
    { file: 'data/Places.csv', field: 'Place Image', type: 'Place' }
  ];
  
  for (const test of tests) {
    console.log(`\n📋 Testing ${test.type} images from ${test.file}...\n`);
    
    const results = [];
    const filePath = path.join(__dirname, test.file);
    
    if (!fs.existsSync(filePath)) {
      console.log(`⚠️  File not found: ${filePath}`);
      continue;
    }
    
    // Read CSV and collect data
    await new Promise((resolve) => {
      fs.createReadStream(filePath)
        .pipe(csv())
        .on('data', (data) => results.push(data))
        .on('end', resolve);
    });
    
    // Test first 3 images with valid data
    let testedCount = 0;
    let successCount = 0;
    
    for (const item of results) {
      if (testedCount >= 3) break;
      
      const imageUrl = extractImageUrl(item[test.field]);
      if (!imageUrl) continue;
      
      console.log(`🧪 Testing ${test.type}: ${item.Email || item['Event Name'] || item['Place Name']}`);
      console.log(`   Raw Image Data: ${item[test.field].substring(0, 150)}...`);
      console.log(`   Extracted URL: ${imageUrl}`);
      
      const result = await testImageUrl(imageUrl);
      if (result.success) {
        successCount++;
        console.log(`✨ Found working URL pattern: ${result.url}\n`);
      } else {
        console.log(`💔 No working URL found for this image\n`);
      }
      
      testedCount++;
    }
    
    console.log(`📊 ${test.type} Results: ${successCount}/${testedCount} images accessible\n`);
  }
  
  console.log('🏁 Image accessibility test completed!');
  console.log('\n💡 Based on the results above, you may need to:');
  console.log('   1. Adjust the URL construction logic in the main script');
  console.log('   2. Check if Adalo requires authentication for image access');
  console.log('   3. Verify your Adalo app configuration');
}

// Run the test
testImageAccess().catch(console.error); 