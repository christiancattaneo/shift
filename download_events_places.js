const https = require('https');
const fs = require('fs');

// Adalo API Configuration
const ADALO_API_KEY = 'e5tvtd15e7hsiipspcv5fhf67';
const APP_ID = 'a03b07ee-0cee-4d06-82bb-75e4f6193332';

// Collection IDs
const EVENTS_COLLECTION_ID = 't_5yzmr55ay7kwytn4mgmofkfnx';
const PLACES_COLLECTION_ID = 't_7ae6bgzwpb4fq71anp1umq261';

const HEADERS = {
    'Authorization': `Bearer ${ADALO_API_KEY}`,
    'Content-Type': 'application/json'
};

// Helper function to make API requests
function makeRequest(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, { headers: HEADERS }, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const jsonData = JSON.parse(data);
                    resolve(jsonData);
                } catch (error) {
                    reject(new Error(`Failed to parse JSON: ${error.message}`));
                }
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        req.setTimeout(30000, () => {
            req.destroy();
            reject(new Error('Request timeout'));
        });
    });
}

// Download all records from a collection with pagination
async function downloadCollection(collectionId, collectionName) {
    console.log(`\n🔄 Starting download of ${collectionName}...`);
    
    let allRecords = [];
    let offset = 0;
    const limit = 100;
    let hasMore = true;
    
    while (hasMore) {
        try {
            const url = `https://api.adalo.com/v0/apps/${APP_ID}/collections/${collectionId}?offset=${offset}&limit=${limit}`;
            console.log(`📥 Fetching ${collectionName} ${offset + 1}-${offset + limit}...`);
            
            const response = await makeRequest(url);
            
            if (response.records && response.records.length > 0) {
                allRecords = allRecords.concat(response.records);
                console.log(`✅ Downloaded ${response.records.length} ${collectionName.toLowerCase()} (Total: ${allRecords.length})`);
                
                offset += limit;
                hasMore = response.records.length === limit;
                
                // Add delay to be respectful to API
                await new Promise(resolve => setTimeout(resolve, 500));
            } else {
                hasMore = false;
            }
        } catch (error) {
            console.error(`❌ Error fetching ${collectionName} at offset ${offset}:`, error.message);
            
            // Retry logic
            console.log('🔄 Retrying in 2 seconds...');
            await new Promise(resolve => setTimeout(resolve, 2000));
            continue;
        }
    }
    
    return allRecords;
}

// Save data to file
function saveDataToFile(data, filename) {
    try {
        const dirPath = './adalo_data';
        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath, { recursive: true });
        }
        
        const filePath = `${dirPath}/${filename}`;
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
        console.log(`💾 Saved ${data.length} records to ${filePath}`);
        return true;
    } catch (error) {
        console.error(`❌ Error saving to ${filename}:`, error.message);
        return false;
    }
}

// Analyze data structure
function analyzeData(data, name) {
    if (!data || data.length === 0) {
        console.log(`📊 ${name}: No data to analyze`);
        return;
    }
    
    console.log(`\n📊 ${name} Analysis:`);
    console.log(`   Total Records: ${data.length}`);
    
    // Get all unique keys
    const allKeys = new Set();
    data.forEach(record => {
        Object.keys(record).forEach(key => allKeys.add(key));
    });
    
    console.log(`   Fields: ${Array.from(allKeys).join(', ')}`);
    
    // Sample record
    console.log(`   Sample Record:`, JSON.stringify(data[0], null, 2));
    
    // Check for image fields
    const imageFields = Array.from(allKeys).filter(key => 
        key.toLowerCase().includes('image') || 
        key.toLowerCase().includes('photo') ||
        key.toLowerCase().includes('picture')
    );
    
    if (imageFields.length > 0) {
        console.log(`   🖼️  Image Fields Found: ${imageFields.join(', ')}`);
        
        // Count records with images
        const withImages = data.filter(record => 
            imageFields.some(field => record[field] && record[field].url)
        ).length;
        
        console.log(`   📸 Records with images: ${withImages}/${data.length}`);
    }
}

// Generate summary
function generateSummary(eventsData, placesData) {
    const summary = {
        downloadedAt: new Date().toISOString(),
        events: {
            total: eventsData.length,
            fields: eventsData.length > 0 ? Object.keys(eventsData[0]) : [],
            sample: eventsData.length > 0 ? eventsData[0] : null
        },
        places: {
            total: placesData.length,
            fields: placesData.length > 0 ? Object.keys(placesData[0]) : [],
            sample: placesData.length > 0 ? placesData[0] : null
        }
    };
    
    saveDataToFile(summary, 'events_places_summary.json');
    return summary;
}

// Main execution
async function main() {
    console.log('🚀 Starting Events & Places Download from Adalo...');
    console.log(`📍 App ID: ${APP_ID}`);
    console.log(`🎪 Events Collection: ${EVENTS_COLLECTION_ID}`);
    console.log(`📍 Places Collection: ${PLACES_COLLECTION_ID}`);
    
    try {
        // Download Events
        const eventsData = await downloadCollection(EVENTS_COLLECTION_ID, 'Events');
        analyzeData(eventsData, 'Events');
        saveDataToFile(eventsData, 'all_events.json');
        
        // Download Places
        const placesData = await downloadCollection(PLACES_COLLECTION_ID, 'Places');
        analyzeData(placesData, 'Places');
        saveDataToFile(placesData, 'all_places.json');
        
        // Generate summary
        const summary = generateSummary(eventsData, placesData);
        
        console.log('\n🎉 DOWNLOAD COMPLETE!');
        console.log('📊 Final Results:');
        console.log(`   Events: ${eventsData.length} records`);
        console.log(`   Places: ${placesData.length} records`);
        console.log(`   Total: ${eventsData.length + placesData.length} records`);
        
        console.log('\n📁 Files Created:');
        console.log('   - adalo_data/all_events.json');
        console.log('   - adalo_data/all_places.json');
        console.log('   - adalo_data/events_places_summary.json');
        
        console.log('\n🎯 Next Steps:');
        console.log('   1. Review the downloaded data');
        console.log('   2. Run migration script to Firebase');
        console.log('   3. Update iOS app to use new data structure');
        
    } catch (error) {
        console.error('💥 Fatal error:', error);
        process.exit(1);
    }
}

// Execute if run directly
if (require.main === module) {
    main();
}

module.exports = { downloadCollection, analyzeData }; 