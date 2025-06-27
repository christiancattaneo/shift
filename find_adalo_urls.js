const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');
const https = require('https');
const http = require('http');
const { URL } = require('url');

// Helper function to extract image URL from Adalo image data
function extractImageData(imageDataString) {
  if (!imageDataString || imageDataString.trim() === '') {
    return null;
  }
  
  try {
    const cleanedString = imageDataString.replace(/'/g, '"');
    const imageData = JSON.parse(cleanedString);
    return imageData;
  } catch (error) {
    console.log(`⚠️  Could not parse image data: ${imageDataString.substring(0, 100)}...`);
    return null;
  }
}

// Function to analyze image data patterns
function analyzeImageData() {
  console.log('🔍 Analyzing Adalo image data patterns...\n');
  
  const files = [
    { path: 'data/Users.csv', field: 'Photo', type: 'User' },
    { path: 'data/Events.csv', field: 'Image', type: 'Event' },
    { path: 'data/Places.csv', field: 'Place Image', type: 'Place' }
  ];
  
  const patterns = new Set();
  const filenames = new Set();
  
  files.forEach(file => {
    if (!fs.existsSync(file.path)) {
      console.log(`⚠️  File not found: ${file.path}`);
      return;
    }
    
    console.log(`📋 Analyzing ${file.type} images from ${file.path}...`);
    
    const results = [];
    fs.createReadStream(file.path)
      .pipe(csv())
      .on('data', (data) => results.push(data))
      .on('end', () => {
        let analyzed = 0;
        
        results.slice(0, 5).forEach(item => {
          const imageData = extractImageData(item[file.field]);
          if (imageData) {
            analyzed++;
            console.log(`\n📸 ${file.type} Image ${analyzed}:`);
            console.log(`   URL: ${imageData.url}`);
            console.log(`   Filename: ${imageData.filename}`);
            console.log(`   Size: ${imageData.size} bytes`);
            console.log(`   Dimensions: ${imageData.width}x${imageData.height}`);
            
            // Extract patterns
            if (imageData.url) {
              patterns.add(imageData.url.length);
              if (imageData.url.includes('.')) {
                const ext = imageData.url.split('.').pop();
                patterns.add(`Extension: .${ext}`);
              }
            }
            
            if (imageData.filename) {
              filenames.add(imageData.filename);
            }
          }
        });
        
        console.log(`\n✅ Analyzed ${analyzed} ${file.type} images\n`);
      });
  });
  
  setTimeout(() => {
    console.log('\n📊 Analysis Summary:');
    console.log('\n🔗 URL Patterns Found:');
    patterns.forEach(pattern => console.log(`   - ${pattern}`));
    
    console.log('\n📁 Sample Filenames:');
    Array.from(filenames).slice(0, 10).forEach(filename => console.log(`   - ${filename}`));
  }, 1000);
}

// Function to suggest Adalo app URL discovery
function suggestUrlDiscovery() {
  console.log('\n\n🔧 SOLUTION STRATEGIES:\n');
  
  console.log('1️⃣  **Find Your Adalo App URL**');
  console.log('   - Log into your Adalo dashboard');
  console.log('   - Go to your Shift app');
  console.log('   - Look for the "Preview" or "View App" button');
  console.log('   - The URL will be something like: https://previewer.adalo.com/[app-id]');
  console.log('   - Or: https://[your-app-name].adalo.app\n');
  
  console.log('2️⃣  **Check Image Access in Adalo**');
  console.log('   - In Adalo, go to your Database');
  console.log('   - Find a user/event with an image');
  console.log('   - Right-click on the image and "Copy Image Address"');
  console.log('   - This will show you the actual URL pattern\n');
  
  console.log('3️⃣  **Try These URL Patterns**');
  console.log('   Replace [APP-URL] with your actual Adalo app URL:');
  console.log('   - https://[APP-URL]/uploads/[IMAGE-HASH].jpg');
  console.log('   - https://[APP-URL]/api/files/[IMAGE-HASH].jpg');
  console.log('   - https://cdn.adalo.com/[APP-ID]/[IMAGE-HASH].jpg');
  console.log('   - https://storage.googleapis.com/adalo-uploads/[IMAGE-HASH].jpg\n');
  
  console.log('4️⃣  **Check Authentication Requirements**');
  console.log('   - Your app might require login to view images');
  console.log('   - Try accessing an image URL while logged into Adalo');
  console.log('   - If it works, you may need to add authentication headers\n');
  
  console.log('5️⃣  **Alternative: Manual Download**');
  console.log('   - Export images directly from Adalo database');
  console.log('   - Or download them manually and place in organized folders');
  console.log('   - Then run a local upload script to Firebase\n');
  
  console.log('6️⃣  **Contact Adalo Support**');
  console.log('   - Ask about programmatic access to uploaded images');
  console.log('   - Request API endpoints for image downloads');
  console.log('   - Check if there\'s a bulk export feature for images\n');
}

// Function to create a manual download guide
function createManualDownloadGuide() {
  console.log('\n📝 Creating manual download guide...\n');
  
  const guideContent = `# Manual Image Download Guide

## If Automatic Download Doesn't Work

### Option 1: Download from Adalo Database

1. Log into your Adalo dashboard
2. Go to Database → Users/Events/Places
3. For each record with an image:
   - Right-click the image → "Save image as..."
   - Save to organized folders:
     - ./manual_images/users/[user-id].jpg
     - ./manual_images/events/[event-id].jpg
     - ./manual_images/places/[place-id].jpg

### Option 2: Use Browser Developer Tools

1. Open your Adalo app in browser
2. Open Developer Tools (F12)
3. Go to Network tab
4. Browse to pages with images
5. In Network tab, filter by "Img"
6. Right-click image requests → "Copy URL"
7. Use these URLs to update the script

### Option 3: Bulk Export Request

Contact Adalo support and request:
- Bulk image export feature
- API endpoint for image downloads
- Documentation on image URL structure

### Option 4: Firebase Direct Upload

If you have images locally:

\`\`\`bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Upload images to Storage
firebase storage:upload ./manual_images/users/ gs://shift-12948.appspot.com/profile_images/
firebase storage:upload ./manual_images/events/ gs://shift-12948.appspot.com/event_images/
firebase storage:upload ./manual_images/places/ gs://shift-12948.appspot.com/place_images/
\`\`\`

### Update Script After Manual Download

If you discover the working URL pattern, update \`image_config.js\`:

\`\`\`javascript
adalo: {
  baseUrls: [
    'https://your-working-url-pattern.com/',
    // Add your discovered URLs here
  ]
}
\`\`\`
`;

  fs.writeFileSync('MANUAL_DOWNLOAD_GUIDE.md', guideContent);
  console.log('✅ Created MANUAL_DOWNLOAD_GUIDE.md');
}

// Function to test a custom URL pattern
function testCustomUrl(baseUrl, imageHash) {
  return new Promise((resolve) => {
    const testUrl = `${baseUrl}${imageHash}`;
    
    try {
      const parsedUrl = new URL(testUrl);
      const protocol = parsedUrl.protocol === 'https:' ? https : http;
      
      const request = protocol.get(testUrl, (response) => {
        console.log(`📍 Testing custom URL: ${testUrl}`);
        console.log(`   Status: ${response.statusCode}`);
        console.log(`   Content-Type: ${response.headers['content-type']}`);
        
        if (response.statusCode === 200 && response.headers['content-type']?.startsWith('image/')) {
          console.log(`✅ SUCCESS: Custom URL works!`);
          resolve({ success: true, url: testUrl });
        } else {
          console.log(`❌ FAILED: Custom URL doesn't work`);
          resolve({ success: false });
        }
        
        response.destroy();
      });
      
      request.on('error', (error) => {
        console.log(`❌ ERROR: ${error.message}`);
        resolve({ success: false, error: error.message });
      });
      
      request.setTimeout(5000, () => {
        request.destroy();
        console.log(`⏱️  TIMEOUT`);
        resolve({ success: false, error: 'timeout' });
      });
    } catch (error) {
      resolve({ success: false, error: error.message });
    }
  });
}

// Interactive URL testing
async function interactiveUrlTest() {
  console.log('\n🧪 INTERACTIVE URL TESTING\n');
  console.log('If you found a working image URL, we can test the pattern:\n');
  
  // Get a sample image hash from the data
  const results = [];
  fs.createReadStream('data/Users.csv')
    .pipe(csv())
    .on('data', (data) => results.push(data))
    .on('end', async () => {
      const sampleUser = results.find(user => user.Photo);
      if (sampleUser) {
        const imageData = extractImageData(sampleUser.Photo);
        if (imageData) {
          const sampleHash = imageData.url;
          console.log(`📸 Sample image hash: ${sampleHash}`);
          console.log(`🔍 If you found a working URL pattern, test it by updating the script!`);
          console.log(`\nExample: If your working URL is:`);
          console.log(`https://your-app.adalo.app/uploads/${sampleHash}`);
          console.log(`\nThen update image_config.js with:`);
          console.log(`baseUrls: ['https://your-app.adalo.app/uploads/']`);
        }
      }
    });
}

// Main function
async function main() {
  console.log('🕵️  ADALO IMAGE URL DETECTIVE\n');
  console.log('This script helps you find the correct URL pattern for your Adalo images.\n');
  
  analyzeImageData();
  
  setTimeout(() => {
    suggestUrlDiscovery();
    createManualDownloadGuide();
    interactiveUrlTest();
    
    console.log('\n🎯 NEXT STEPS:');
    console.log('1. Try the strategies above to find your Adalo image URLs');
    console.log('2. Update image_config.js with the working URL pattern');
    console.log('3. Run: npm run test-images');
    console.log('4. If successful, run: npm run download-images\n');
    
  }, 2000);
}

main().catch(console.error); 