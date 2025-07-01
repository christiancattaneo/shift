const https = require('https');
const fs = require('fs');
const path = require('path');

// Load the downloaded data
function loadData() {
    try {
        const eventsData = JSON.parse(fs.readFileSync('./adalo_data/all_events.json', 'utf8'));
        const placesData = JSON.parse(fs.readFileSync('./adalo_data/all_places.json', 'utf8'));
        return { eventsData, placesData };
    } catch (error) {
        console.error('❌ Error loading data files:', error.message);
        console.log('🔄 Please run download_events_places.js first');
        process.exit(1);
    }
}

// Create directories for organizing images
function createDirectories() {
    const dirs = [
        './adalo_data/event_images',
        './adalo_data/place_images'
    ];
    
    dirs.forEach(dir => {
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
            console.log(`📁 Created directory: ${dir}`);
        }
    });
}

// Download image from URL
function downloadImage(url, filepath) {
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(filepath);
        
        const request = https.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
                return;
            }
            
            response.pipe(file);
            
            file.on('finish', () => {
                file.close();
                resolve();
            });
            
            file.on('error', (err) => {
                fs.unlink(filepath, () => {}); // Delete the file on error
                reject(err);
            });
        });
        
        request.on('error', (err) => {
            reject(err);
        });
        
        request.setTimeout(30000, () => {
            request.destroy();
            reject(new Error('Download timeout'));
        });
    });
}

// Get file extension from URL or filename
function getFileExtension(url, filename) {
    if (filename && filename.includes('.')) {
        return path.extname(filename).toLowerCase();
    }
    
    // Try to extract from URL
    const urlPath = url.split('?')[0]; // Remove query parameters
    const ext = path.extname(urlPath).toLowerCase();
    
    if (ext && ['.jpg', '.jpeg', '.png', '.gif', '.webp'].includes(ext)) {
        return ext;
    }
    
    // Default to .jpg
    return '.jpg';
}

// Download event images
async function downloadEventImages(eventsData) {
    console.log('\n🎪 DOWNLOADING EVENT IMAGES...');
    
    const eventsWithImages = eventsData.filter(event => event.Image && event.Image.url);
    console.log(`📊 Found ${eventsWithImages.length} events with images out of ${eventsData.length} total events`);
    
    const results = {
        total: eventsWithImages.length,
        successful: 0,
        failed: 0,
        failedItems: []
    };
    
    for (let i = 0; i < eventsWithImages.length; i++) {
        const event = eventsWithImages[i];
        const imageUrl = event.Image.url;
        const eventId = event.id;
        const eventName = event['Event Name'] || event['Venue Name'] || `Event_${eventId}`;
        
        try {
            // Clean filename
            const cleanName = eventName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
            const fileExtension = getFileExtension(imageUrl, event.Image.filename);
            const filename = `${eventId}_${cleanName}${fileExtension}`;
            const filepath = `./adalo_data/event_images/${filename}`;
            
            console.log(`📥 [${i + 1}/${eventsWithImages.length}] Downloading: ${eventName}`);
            console.log(`   🔗 URL: ${imageUrl}`);
            console.log(`   💾 File: ${filename}`);
            
            await downloadImage(imageUrl, filepath);
            
            results.successful++;
            console.log(`   ✅ Success!`);
            
            // Add small delay to be respectful
            await new Promise(resolve => setTimeout(resolve, 200));
            
        } catch (error) {
            results.failed++;
            results.failedItems.push({
                id: eventId,
                name: eventName,
                url: imageUrl,
                error: error.message
            });
            
            console.log(`   ❌ Failed: ${error.message}`);
        }
    }
    
    return results;
}

// Download place images
async function downloadPlaceImages(placesData) {
    console.log('\n📍 DOWNLOADING PLACE IMAGES...');
    
    const placesWithImages = placesData.filter(place => place['Place Image'] && place['Place Image'].url);
    console.log(`📊 Found ${placesWithImages.length} places with images out of ${placesData.length} total places`);
    
    const results = {
        total: placesWithImages.length,
        successful: 0,
        failed: 0,
        failedItems: []
    };
    
    for (let i = 0; i < placesWithImages.length; i++) {
        const place = placesWithImages[i];
        const imageUrl = place['Place Image'].url;
        const placeId = place.id;
        const placeName = place['Place Name'] || `Place_${placeId}`;
        
        try {
            // Clean filename
            const cleanName = placeName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
            const fileExtension = getFileExtension(imageUrl, place['Place Image'].filename);
            const filename = `${placeId}_${cleanName}${fileExtension}`;
            const filepath = `./adalo_data/place_images/${filename}`;
            
            console.log(`📥 [${i + 1}/${placesWithImages.length}] Downloading: ${placeName}`);
            console.log(`   🔗 URL: ${imageUrl}`);
            console.log(`   💾 File: ${filename}`);
            
            await downloadImage(imageUrl, filepath);
            
            results.successful++;
            console.log(`   ✅ Success!`);
            
            // Add small delay to be respectful
            await new Promise(resolve => setTimeout(resolve, 200));
            
        } catch (error) {
            results.failed++;
            results.failedItems.push({
                id: placeId,
                name: placeName,
                url: imageUrl,
                error: error.message
            });
            
            console.log(`   ❌ Failed: ${error.message}`);
        }
    }
    
    return results;
}

// Generate download summary
function generateDownloadSummary(eventResults, placeResults) {
    const summary = {
        downloadedAt: new Date().toISOString(),
        events: {
            total: eventResults.total,
            successful: eventResults.successful,
            failed: eventResults.failed,
            successRate: eventResults.total > 0 ? ((eventResults.successful / eventResults.total) * 100).toFixed(1) : 0,
            failedItems: eventResults.failedItems
        },
        places: {
            total: placeResults.total,
            successful: placeResults.successful,
            failed: placeResults.failed,
            successRate: placeResults.total > 0 ? ((placeResults.successful / placeResults.total) * 100).toFixed(1) : 0,
            failedItems: placeResults.failedItems
        },
        totals: {
            images: eventResults.total + placeResults.total,
            successful: eventResults.successful + placeResults.successful,
            failed: eventResults.failed + placeResults.failed
        }
    };
    
    // Save summary
    try {
        fs.writeFileSync('./adalo_data/images_download_summary.json', JSON.stringify(summary, null, 2));
        console.log('💾 Saved download summary to: ./adalo_data/images_download_summary.json');
    } catch (error) {
        console.error('❌ Error saving summary:', error.message);
    }
    
    return summary;
}

// Main execution
async function main() {
    console.log('🚀 Starting Event & Place Images Download...');
    
    // Load data
    const { eventsData, placesData } = loadData();
    
    // Create directories
    createDirectories();
    
    try {
        // Download event images
        const eventResults = await downloadEventImages(eventsData);
        
        // Download place images
        const placeResults = await downloadPlaceImages(placesData);
        
        // Generate summary
        const summary = generateDownloadSummary(eventResults, placeResults);
        
        console.log('\n🎉 DOWNLOAD COMPLETE!');
        console.log('📊 Final Results:');
        console.log(`   Event Images: ${eventResults.successful}/${eventResults.total} (${eventResults.total > 0 ? ((eventResults.successful / eventResults.total) * 100).toFixed(1) : 0}% success)`);
        console.log(`   Place Images: ${placeResults.successful}/${placeResults.total} (${placeResults.total > 0 ? ((placeResults.successful / placeResults.total) * 100).toFixed(1) : 0}% success)`);
        console.log(`   Total Images: ${summary.totals.successful}/${summary.totals.images}`);
        
        if (summary.totals.failed > 0) {
            console.log(`\n⚠️  ${summary.totals.failed} images failed to download`);
            console.log('Check images_download_summary.json for details');
        }
        
        console.log('\n📁 Images saved to:');
        console.log('   - adalo_data/event_images/');
        console.log('   - adalo_data/place_images/');
        
        console.log('\n🎯 Next Steps:');
        console.log('   1. Run Firebase migration for Events & Places');
        console.log('   2. Upload images to Firebase Storage');
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

module.exports = { downloadEventImages, downloadPlaceImages }; 