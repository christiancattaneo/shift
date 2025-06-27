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
    users: 't_922b75d1c0b749eca8271685ae718d82',
    events: 't_5yzmr55ay7kwytn4mgmofkfnx', 
    places: 't_7ae6bgzwpb4fq71anp1umq261'
  }
};

// Create organized directory structure
const baseDir = './all_adalo_images';
const dirs = {
  users: path.join(baseDir, 'users'),
  events: path.join(baseDir, 'events'),
  places: path.join(baseDir, 'places')
};

function createDirectories() {
  Object.values(dirs).forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
  
  if (!fs.existsSync(baseDir)) {
    fs.mkdirSync(baseDir, { recursive: true });
  }
}

// Helper function to sanitize filename
function sanitizeFilename(filename) {
  if (!filename) return 'unknown';
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

// Function to fetch all records from a collection
async function fetchAllRecords(collectionId, collectionName) {
  const allRecords = [];
  let offset = 0;
  const limit = 1000;
  
  console.log(`🔍 Fetching all ${collectionName} records...`);
  
  while (true) {
    try {
      const url = `${ADALO_CONFIG.baseUrl}/collections/${collectionId}?limit=${limit}&offset=${offset}`;
      
      const options = {
        headers: {
          'Authorization': ADALO_CONFIG.authToken,
          'Content-Type': 'application/json'
        }
      };
      
      const response = await new Promise((resolve, reject) => {
        https.get(url, options, (res) => {
          let data = '';
          res.on('data', (chunk) => data += chunk);
          res.on('end', () => {
            try {
              resolve(JSON.parse(data));
            } catch (error) {
              reject(error);
            }
          });
        }).on('error', reject);
      });
      
      const records = response.records || response;
      if (!records || records.length === 0) {
        break;
      }
      
      allRecords.push(...records);
      console.log(`   📄 Fetched ${records.length} records (total: ${allRecords.length})`);
      
      if (records.length < limit) {
        break;
      }
      
      offset += limit;
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`❌ Error fetching ${collectionName}:`, error.message);
      break;
    }
  }
  
  return allRecords;
}

// Function to process and download images for a collection
async function processCollection(collectionKey, collectionId, collectionName) {
  console.log(`\n🚀 Processing ${collectionName} collection...`);
  
  const records = await fetchAllRecords(collectionId, collectionName);
  const targetDir = dirs[collectionKey];
  
  let successCount = 0;
  let errorCount = 0;
  let noImageCount = 0;
  const downloadSummary = [];
  
  for (let i = 0; i < records.length; i++) {
    const record = records[i];
    let imageData = null;
    let identifier = '';
    
    // Get image data and identifier based on collection type
    if (collectionKey === 'users') {
      imageData = record.Photo;
      identifier = `${i + 1}_${sanitizeFilename(record.Email || 'unknown')}`;
    } else if (collectionKey === 'events') {
      imageData = record.Image;
      identifier = `${i + 1}_${sanitizeFilename(record['Event Name'] || record['Venue Name'] || 'unknown_event')}`;
    } else if (collectionKey === 'places') {
      imageData = record['Place Image'];
      identifier = `${i + 1}_${sanitizeFilename(record['Place Name'] || 'unknown_place')}`;
    }
    
    console.log(`\n📂 Processing ${collectionName} ${i + 1}/${records.length}: ${identifier}`);
    
    // Create individual directory for this record
    const recordDir = path.join(targetDir, identifier);
    if (!fs.existsSync(recordDir)) {
      fs.mkdirSync(recordDir, { recursive: true });
    }
    
    // Save record info as JSON
    const recordInfo = {
      id: record.id,
      collectionType: collectionKey,
      ...record,
      downloadedAt: new Date().toISOString()
    };
    
    fs.writeFileSync(
      path.join(recordDir, 'record_info.json'), 
      JSON.stringify(recordInfo, null, 2)
    );
    
    // Process image if available
    if (!imageData || !imageData.url) {
      console.log(`⚠️  No image available`);
      noImageCount++;
      downloadSummary.push({
        identifier,
        status: 'no_image',
        message: 'No image data available'
      });
      continue;
    }
    
    try {
      const imageUrl = imageData.url;
      const originalFilename = imageData.filename || 'image';
      const extension = path.extname(originalFilename) || '.jpg';
      const fileName = `${collectionKey}_${sanitizeFilename(originalFilename)}`;
      
      console.log(`📸 Image URL: ${imageUrl}`);
      console.log(`📁 Filename: ${originalFilename}`);
      
      // Download image
      const localPath = path.join(recordDir, fileName);
      await downloadImage(imageUrl, localPath);
      
      successCount++;
      downloadSummary.push({
        identifier,
        status: 'success',
        localPath: localPath,
        originalUrl: imageUrl,
        filename: fileName,
        size: imageData.size,
        dimensions: `${imageData.width}x${imageData.height}`
      });
      
    } catch (error) {
      console.error(`❌ Error downloading image:`, error.message);
      errorCount++;
      downloadSummary.push({
        identifier,
        status: 'error',
        message: error.message,
        originalUrl: imageData.url
      });
    }
  }
  
  return {
    collectionName,
    totalRecords: records.length,
    successCount,
    errorCount,
    noImageCount,
    downloadSummary
  };
}

// Main function to download all images
async function downloadAllImages() {
  console.log('🚀 Starting comprehensive image download from ALL Adalo collections...\n');
  
  createDirectories();
  
  const results = {
    timestamp: new Date().toISOString(),
    collections: {},
    totals: {
      totalRecords: 0,
      totalDownloaded: 0,
      totalErrors: 0,
      totalNoImages: 0
    }
  };
  
  // Process each collection
  for (const [key, collectionId] of Object.entries(ADALO_CONFIG.collections)) {
    const collectionName = key.charAt(0).toUpperCase() + key.slice(1);
    
    try {
      const result = await processCollection(key, collectionId, collectionName);
      results.collections[key] = result;
      
      // Update totals
      results.totals.totalRecords += result.totalRecords;
      results.totals.totalDownloaded += result.successCount;
      results.totals.totalErrors += result.errorCount;
      results.totals.totalNoImages += result.noImageCount;
      
    } catch (error) {
      console.error(`❌ Failed to process ${collectionName}:`, error.message);
      results.collections[key] = {
        error: error.message
      };
    }
    
    // Small delay between collections
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  
  // Save comprehensive summary
  const summaryPath = path.join(baseDir, 'complete_download_summary.json');
  fs.writeFileSync(summaryPath, JSON.stringify(results, null, 2));
  
  // Print final summary
  console.log('\n' + '='.repeat(60));
  console.log('🎉 COMPLETE IMAGE DOWNLOAD FINISHED!');
  console.log('='.repeat(60));
  
  console.log(`\n📊 OVERALL RESULTS:`);
  console.log(`   📋 Total Records Processed: ${results.totals.totalRecords}`);
  console.log(`   ✅ Images Downloaded: ${results.totals.totalDownloaded}`);
  console.log(`   ❌ Download Errors: ${results.totals.totalErrors}`);
  console.log(`   ⚠️  No Images Available: ${results.totals.totalNoImages}`);
  
  console.log(`\n📂 COLLECTION BREAKDOWN:`);
  Object.entries(results.collections).forEach(([key, data]) => {
    if (data.error) {
      console.log(`\n❌ ${key.toUpperCase()}: ERROR - ${data.error}`);
    } else {
      console.log(`\n👥 ${key.toUpperCase()}:`);
      console.log(`   📋 Records: ${data.totalRecords}`);
      console.log(`   ✅ Downloaded: ${data.successCount}`);
      console.log(`   ❌ Errors: ${data.errorCount}`);
      console.log(`   ⚠️  No Images: ${data.noImageCount}`);
    }
  });
  
  console.log(`\n📁 Files saved to: ${path.resolve(baseDir)}`);
  console.log(`📋 Summary saved to: ${path.resolve(summaryPath)}`);
  
  console.log(`\n🎯 NEXT STEPS:`);
  console.log(`   1. Enable Firebase Storage in your console`);
  console.log(`   2. Run: npm run test-firebase (verify storage)`);
  console.log(`   3. Run: npm run upload-all-to-firebase (upload everything)`);
  
  return results;
}

// Export and run
module.exports = { downloadAllImages, processCollection, fetchAllRecords };

if (require.main === module) {
  downloadAllImages().catch(console.error);
} 