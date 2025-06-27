require('dotenv').config();
const https = require('https');

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

// Function to fetch all records from a collection with pagination
async function fetchAllRecords(collectionId, collectionName) {
  const allRecords = [];
  let offset = 0;
  const limit = 1000; // Max records per page
  
  console.log(`🔍 Analyzing ${collectionName} collection...`);
  
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
      
      // If we got fewer than the limit, we're done
      if (records.length < limit) {
        break;
      }
      
      offset += limit;
      
      // Small delay to be respectful
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`❌ Error fetching ${collectionName}:`, error.message);
      break;
    }
  }
  
  return allRecords;
}

// Function to analyze images in records
function analyzeImages(records, collectionName) {
  let totalRecords = records.length;
  let recordsWithImages = 0;
  let totalImages = 0;
  let imageDetails = [];
  
  console.log(`\n📊 Analyzing images in ${collectionName}...`);
  
  records.forEach((record, index) => {
    let hasImage = false;
    let imageData = null;
    
    // Different collections have different image field names
    if (collectionName === 'Users') {
      imageData = record.Photo;
    } else if (collectionName === 'Events') {
      imageData = record.Image;
    } else if (collectionName === 'Places') {
      imageData = record['Place Image'];
    }
    
    if (imageData && imageData.url) {
      hasImage = true;
      recordsWithImages++;
      totalImages++;
      
      imageDetails.push({
        id: record.id,
        email: record.Email || null,
        name: record['First Name'] || record['Event Name'] || record['Place Name'] || 'Unknown',
        imageUrl: imageData.url,
        filename: imageData.filename,
        size: imageData.size,
        width: imageData.width,
        height: imageData.height
      });
    }
  });
  
  return {
    collectionName,
    totalRecords,
    recordsWithImages,
    totalImages,
    imageDetails,
    percentageWithImages: totalRecords > 0 ? ((recordsWithImages / totalRecords) * 100).toFixed(1) : 0
  };
}

// Main analysis function
async function analyzeAllCollections() {
  console.log('🚀 Starting comprehensive Adalo analysis...\n');
  
  const results = {
    timestamp: new Date().toISOString(),
    collections: {},
    totals: {
      totalRecords: 0,
      totalRecordsWithImages: 0,
      totalImages: 0
    }
  };
  
  // Analyze each collection
  for (const [key, collectionId] of Object.entries(ADALO_CONFIG.collections)) {
    const collectionName = key.charAt(0).toUpperCase() + key.slice(1);
    
    try {
      // Fetch all records
      const records = await fetchAllRecords(collectionId, collectionName);
      
      // Analyze images
      const analysis = analyzeImages(records, collectionName);
      
      results.collections[key] = {
        ...analysis,
        collectionId,
        sampleRecords: records.slice(0, 3) // First 3 records for reference
      };
      
      // Update totals
      results.totals.totalRecords += analysis.totalRecords;
      results.totals.totalRecordsWithImages += analysis.recordsWithImages;
      results.totals.totalImages += analysis.totalImages;
      
    } catch (error) {
      console.error(`❌ Failed to analyze ${collectionName}:`, error.message);
      results.collections[key] = {
        error: error.message
      };
    }
  }
  
  // Print comprehensive summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 COMPREHENSIVE ADALO ANALYSIS RESULTS');
  console.log('='.repeat(60));
  
  console.log(`\n🎯 OVERALL TOTALS:`);
  console.log(`   📋 Total Records: ${results.totals.totalRecords}`);
  console.log(`   🖼️  Total Images: ${results.totals.totalImages}`);
  console.log(`   📊 Records with Images: ${results.totals.totalRecordsWithImages}`);
  console.log(`   📈 Overall Image Coverage: ${results.totals.totalRecords > 0 ? ((results.totals.totalRecordsWithImages / results.totals.totalRecords) * 100).toFixed(1) : 0}%`);
  
  console.log(`\n📑 COLLECTION BREAKDOWN:`);
  
  Object.entries(results.collections).forEach(([key, data]) => {
    if (data.error) {
      console.log(`\n❌ ${data.collectionName}: ERROR - ${data.error}`);
      return;
    }
    
    console.log(`\n👥 ${data.collectionName.toUpperCase()}:`);
    console.log(`   📋 Total Records: ${data.totalRecords}`);
    console.log(`   🖼️  Images Available: ${data.totalImages}`);
    console.log(`   📊 Coverage: ${data.percentageWithImages}%`);
    
    if (data.totalImages > 0) {
      console.log(`   📷 Sample Images:`);
      data.imageDetails.slice(0, 3).forEach((img, i) => {
        console.log(`      ${i + 1}. ${img.name} - ${img.filename} (${(img.size / 1024).toFixed(1)}KB)`);
      });
    }
  });
  
  console.log(`\n📂 WHAT WE HAVE LOCALLY:`);
  console.log(`   ✅ User Images Downloaded: 109 (from previous run)`);
  console.log(`   ⏳ Event Images: Need to download`);
  console.log(`   ⏳ Place Images: Need to download`);
  
  console.log(`\n🎯 NEXT STEPS:`);
  console.log(`   1. Run: npm run download-all-images (download everything)`);
  console.log(`   2. Enable Firebase Storage in console`);
  console.log(`   3. Run: npm run upload-all-to-firebase`);
  
  return results;
}

// Quick stats function
async function getQuickStats() {
  console.log('📊 Getting quick statistics...\n');
  
  const promises = Object.entries(ADALO_CONFIG.collections).map(async ([key, collectionId]) => {
    try {
      const url = `${ADALO_CONFIG.baseUrl}/collections/${collectionId}?limit=1`;
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
      
      return {
        collection: key,
        hasRecords: response.records && response.records.length > 0,
        sampleRecord: response.records ? response.records[0] : null
      };
    } catch (error) {
      return {
        collection: key,
        error: error.message
      };
    }
  });
  
  const results = await Promise.all(promises);
  
  results.forEach(result => {
    if (result.error) {
      console.log(`❌ ${result.collection}: ${result.error}`);
    } else {
      console.log(`✅ ${result.collection}: ${result.hasRecords ? 'Has data' : 'Empty'}`);
    }
  });
  
  console.log('\nRun "npm run full-analysis" for complete statistics.');
}

// Export functions
module.exports = {
  analyzeAllCollections,
  getQuickStats,
  fetchAllRecords,
  analyzeImages
};

// Run based on command line argument
if (require.main === module) {
  const arg = process.argv[2];
  
  if (arg === 'quick') {
    getQuickStats().catch(console.error);
  } else {
    analyzeAllCollections().catch(console.error);
  }
} 