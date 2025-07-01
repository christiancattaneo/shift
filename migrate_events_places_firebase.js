const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
    try {
        const serviceAccount = require('./firebase-admin-key.json');
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            storageBucket: 'shift-79a0c.appspot.com'
        });
        console.log('🔥 Firebase Admin initialized successfully');
    } catch (error) {
        console.error('❌ Failed to initialize Firebase:', error.message);
        process.exit(1);
    }
}

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Configure Firestore to ignore undefined properties
db.settings({ ignoreUndefinedProperties: true });

// Load downloaded data
function loadData() {
    try {
        const eventsData = JSON.parse(fs.readFileSync('./adalo_data/all_events.json', 'utf8'));
        const placesData = JSON.parse(fs.readFileSync('./adalo_data/all_places.json', 'utf8'));
        console.log(`📊 Loaded ${eventsData.length} events and ${placesData.length} places`);
        return { eventsData, placesData };
    } catch (error) {
        console.error('❌ Error loading data files:', error.message);
        console.log('🔄 Please run download_events_places.js first');
        process.exit(1);
    }
}

// Upload image to Firebase Storage
async function uploadImageToStorage(localPath, storagePath) {
    try {
        if (!fs.existsSync(localPath)) {
            throw new Error(`Local file does not exist: ${localPath}`);
        }

        await bucket.upload(localPath, {
            destination: storagePath,
            metadata: {
                cacheControl: 'public, max-age=3600',
            },
        });

        // Get the public download URL
        const file = bucket.file(storagePath);
        await file.makePublic();
        
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        return publicUrl;
    } catch (error) {
        console.error(`❌ Error uploading ${localPath}:`, error.message);
        return null;
    }
}

// Create Firebase Event document
function createFirebaseEvent(adaloEvent, imageURL = null) {
    const firebaseEventId = uuidv4();
    
    const firebaseEvent = {
        // Generate new UUID for Firebase
        id: firebaseEventId,
        
        // Adalo reference (for migration tracking)
        adaloId: adaloEvent.id,
        
        // Event details
        name: adaloEvent['Event Name'] || adaloEvent['Venue Name'] || 'Unnamed Event',
        venueName: adaloEvent['Venue Name'] || null,
        
        // Location data
        address: adaloEvent['Event Location']?.fullAddress || null,
        city: adaloEvent['Event Location']?.addressElements?.city || null,
        state: adaloEvent['Event Location']?.addressElements?.region || null,
        country: adaloEvent['Event Location']?.addressElements?.country || null,
        coordinates: adaloEvent['Event Location']?.coordinates ? {
            latitude: adaloEvent['Event Location'].coordinates.latitude,
            longitude: adaloEvent['Event Location'].coordinates.longitude
        } : null,
        placeId: adaloEvent['Event Location']?.placeId || null,
        
        // Event metadata
        category: adaloEvent['Event Category'] || null,
        isFree: adaloEvent['Is Event Free'] || false,
        
        // Dates and times
        eventDate: adaloEvent['Event DATE'] ? new Date(adaloEvent['Event DATE']) : null,
        startTime: adaloEvent['Event Start Time'] ? new Date(adaloEvent['Event Start Time']) : null,
        endTime: adaloEvent['Event End Time'] ? new Date(adaloEvent['Event End Time']) : null,
        
        // Image
        imageURL: imageURL,
        hasImage: !!imageURL,
        
        // Attendees (from Adalo Users array)
        attendeeCount: Array.isArray(adaloEvent.Users) ? adaloEvent.Users.length : 0,
        attendeeIds: Array.isArray(adaloEvent.Users) ? adaloEvent.Users : [],
        
        // Metadata
        createdAt: adaloEvent.created_at ? new Date(adaloEvent.created_at) : new Date(),
        updatedAt: adaloEvent.updated_at ? new Date(adaloEvent.updated_at) : new Date(),
        
        // Search helpers
        searchTerms: [
            adaloEvent['Event Name'],
            adaloEvent['Venue Name'],
            adaloEvent['Event Category'],
            adaloEvent['Event Location']?.name,
            adaloEvent['Event Location']?.addressElements?.city
        ].filter(Boolean).map(term => term.toLowerCase()),
        
        // Additional Adalo fields (for reference)
        place: adaloEvent.Place || null
    };
    
    return { firebaseEvent, firebaseEventId };
}

// Create Firebase Place document
function createFirebasePlace(adaloPlace, imageURL = null) {
    const firebasePlaceId = uuidv4();
    
    const firebasePlace = {
        // Generate new UUID for Firebase
        id: firebasePlaceId,
        
        // Adalo reference (for migration tracking)
        adaloId: adaloPlace.id,
        
        // Place details
        name: adaloPlace['Place Name'] || 'Unnamed Place',
        
        // Location data
        address: adaloPlace['Place Locatioon']?.fullAddress || null,
        city: adaloPlace['Place Locatioon']?.addressElements?.city || null,
        state: adaloPlace['Place Locatioon']?.addressElements?.region || null,
        country: adaloPlace['Place Locatioon']?.addressElements?.country || null,
        coordinates: adaloPlace['Place Locatioon']?.coordinates ? {
            latitude: adaloPlace['Place Locatioon'].coordinates.latitude,
            longitude: adaloPlace['Place Locatioon'].coordinates.longitude
        } : null,
        placeId: adaloPlace['Place Locatioon']?.placeId || null,
        
        // Place metadata
        isFree: adaloPlace['is place free'] || false,
        
        // Image
        imageURL: imageURL,
        hasImage: !!imageURL,
        
        // Users who have been here (from Adalo Users array)
        visitorCount: Array.isArray(adaloPlace.Users) ? adaloPlace.Users.length : 0,
        visitorIds: Array.isArray(adaloPlace.Users) ? adaloPlace.Users : [],
        
        // Metadata
        createdAt: adaloPlace.created_at ? new Date(adaloPlace.created_at) : new Date(),
        updatedAt: adaloPlace.updated_at ? new Date(adaloPlace.updated_at) : new Date(),
        
        // Search helpers
        searchTerms: [
            adaloPlace['Place Name'],
            adaloPlace['Place Locatioon']?.name,
            adaloPlace['Place Locatioon']?.addressElements?.city
        ].filter(Boolean).map(term => term.toLowerCase())
    };
    
    return { firebasePlace, firebasePlaceId };
}

// Migrate Events to Firebase
async function migrateEvents(eventsData) {
    console.log('\n🎪 MIGRATING EVENTS TO FIREBASE...');
    
    const results = {
        total: eventsData.length,
        successful: 0,
        failed: 0,
        withImages: 0,
        failedItems: []
    };
    
    for (let i = 0; i < eventsData.length; i++) {
        const adaloEvent = eventsData[i];
        const eventId = adaloEvent.id;
        const eventName = adaloEvent['Event Name'] || adaloEvent['Venue Name'] || `Event_${eventId}`;
        
        try {
            console.log(`📥 [${i + 1}/${eventsData.length}] Migrating: ${eventName}`);
            
            let imageURL = null;
            const { firebaseEvent, firebaseEventId } = createFirebaseEvent(adaloEvent);
            
            // Handle image upload if exists
            if (adaloEvent.Image && adaloEvent.Image.url) {
                const cleanName = eventName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
                const fileExtension = adaloEvent.Image.filename ? 
                    path.extname(adaloEvent.Image.filename).toLowerCase() : '.jpg';
                const localImagePath = `./adalo_data/event_images/${eventId}_${cleanName}${fileExtension}`;
                
                if (fs.existsSync(localImagePath)) {
                    const storagePath = `events/${firebaseEventId}${fileExtension}`;
                    
                    console.log(`   📸 Uploading image: ${storagePath}`);
                    imageURL = await uploadImageToStorage(localImagePath, storagePath);
                    
                    if (imageURL) {
                        results.withImages++;
                        firebaseEvent.imageURL = imageURL;
                        firebaseEvent.hasImage = true;
                        console.log(`   ✅ Image uploaded successfully`);
                    } else {
                        console.log(`   ⚠️  Image upload failed, continuing without image`);
                    }
                } else {
                    console.log(`   ⚠️  Local image file not found: ${localImagePath}`);
                }
            }
            
            // Save to Firestore
            await db.collection('events').doc(firebaseEventId).set(firebaseEvent);
            
            results.successful++;
            console.log(`   ✅ Event migrated successfully`);
            
        } catch (error) {
            results.failed++;
            results.failedItems.push({
                adaloId: eventId,
                name: eventName,
                error: error.message
            });
            
            console.log(`   ❌ Failed: ${error.message}`);
        }
        
        // Add small delay to avoid overwhelming Firebase
        if (i % 10 === 0 && i > 0) {
            console.log(`   ⏸️  Pausing briefly...`);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
    
    return results;
}

// Migrate Places to Firebase
async function migratePlaces(placesData) {
    console.log('\n📍 MIGRATING PLACES TO FIREBASE...');
    
    const results = {
        total: placesData.length,
        successful: 0,
        failed: 0,
        withImages: 0,
        failedItems: []
    };
    
    for (let i = 0; i < placesData.length; i++) {
        const adaloPlace = placesData[i];
        const placeId = adaloPlace.id;
        const placeName = adaloPlace['Place Name'] || `Place_${placeId}`;
        
        try {
            console.log(`📥 [${i + 1}/${placesData.length}] Migrating: ${placeName}`);
            
            let imageURL = null;
            const { firebasePlace, firebasePlaceId } = createFirebasePlace(adaloPlace);
            
            // Handle image upload if exists
            if (adaloPlace['Place Image'] && adaloPlace['Place Image'].url) {
                const cleanName = placeName.replace(/[^a-zA-Z0-9]/g, '_').substring(0, 50);
                const fileExtension = adaloPlace['Place Image'].filename ? 
                    path.extname(adaloPlace['Place Image'].filename).toLowerCase() : '.jpg';
                const localImagePath = `./adalo_data/place_images/${placeId}_${cleanName}${fileExtension}`;
                
                if (fs.existsSync(localImagePath)) {
                    const storagePath = `places/${firebasePlaceId}${fileExtension}`;
                    
                    console.log(`   📸 Uploading image: ${storagePath}`);
                    imageURL = await uploadImageToStorage(localImagePath, storagePath);
                    
                    if (imageURL) {
                        results.withImages++;
                        firebasePlace.imageURL = imageURL;
                        firebasePlace.hasImage = true;
                        console.log(`   ✅ Image uploaded successfully`);
                    } else {
                        console.log(`   ⚠️  Image upload failed, continuing without image`);
                    }
                } else {
                    console.log(`   ⚠️  Local image file not found: ${localImagePath}`);
                }
            }
            
            // Save to Firestore
            await db.collection('places').doc(firebasePlaceId).set(firebasePlace);
            
            results.successful++;
            console.log(`   ✅ Place migrated successfully`);
            
        } catch (error) {
            results.failed++;
            results.failedItems.push({
                adaloId: placeId,
                name: placeName,
                error: error.message
            });
            
            console.log(`   ❌ Failed: ${error.message}`);
        }
        
        // Add small delay to avoid overwhelming Firebase
        if (i % 10 === 0 && i > 0) {
            console.log(`   ⏸️  Pausing briefly...`);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
    
    return results;
}

// Generate migration summary
function generateMigrationSummary(eventResults, placeResults) {
    const summary = {
        migrationDate: new Date().toISOString(),
        events: {
            total: eventResults.total,
            successful: eventResults.successful,
            failed: eventResults.failed,
            withImages: eventResults.withImages,
            successRate: ((eventResults.successful / eventResults.total) * 100).toFixed(1),
            failedItems: eventResults.failedItems
        },
        places: {
            total: placeResults.total,
            successful: placeResults.successful,
            failed: placeResults.failed,
            withImages: placeResults.withImages,
            successRate: ((placeResults.successful / placeResults.total) * 100).toFixed(1),
            failedItems: placeResults.failedItems
        },
        totals: {
            records: eventResults.total + placeResults.total,
            successful: eventResults.successful + placeResults.successful,
            failed: eventResults.failed + placeResults.failed,
            images: eventResults.withImages + placeResults.withImages
        }
    };
    
    // Save summary
    try {
        const dirPath = './firebase_migration_data';
        if (!fs.existsSync(dirPath)) {
            fs.mkdirSync(dirPath, { recursive: true });
        }
        
        fs.writeFileSync(`${dirPath}/events_places_migration_summary.json`, JSON.stringify(summary, null, 2));
        console.log('💾 Migration summary saved');
    } catch (error) {
        console.error('❌ Error saving summary:', error.message);
    }
    
    return summary;
}

// Main execution
async function main() {
    console.log('🚀 Starting Events & Places Firebase Migration...');
    console.log('🔥 Firebase Storage Bucket: shift-79a0c.appspot.com');
    
    // Load data
    const { eventsData, placesData } = loadData();
    
    try {
        // Migrate Events
        const eventResults = await migrateEvents(eventsData);
        
        // Migrate Places
        const placeResults = await migratePlaces(placesData);
        
        // Generate summary
        const summary = generateMigrationSummary(eventResults, placeResults);
        
        console.log('\n🎉 MIGRATION COMPLETE!');
        console.log('📊 Final Results:');
        console.log(`   Events: ${eventResults.successful}/${eventResults.total} (${eventResults.successRate}% success)`);
        console.log(`     - With Images: ${eventResults.withImages}`);
        console.log(`   Places: ${placeResults.successful}/${placeResults.total} (${placeResults.successRate}% success)`);
        console.log(`     - With Images: ${placeResults.withImages}`);
        console.log(`   Total Records: ${summary.totals.successful}/${summary.totals.records}`);
        console.log(`   Total Images: ${summary.totals.images}`);
        
        if (summary.totals.failed > 0) {
            console.log(`\n⚠️  ${summary.totals.failed} records failed to migrate`);
            console.log('Check events_places_migration_summary.json for details');
        }
        
        console.log('\n🔥 BENEFITS ACHIEVED:');
        console.log('   ✅ Zero Adalo dependency for Events & Places');
        console.log('   ✅ Clean UUID system');
        console.log('   ✅ Proper Firebase structure');
        console.log('   ✅ Images stored in Firebase Storage');
        console.log('   ✅ Scalable for future growth');
        
        console.log('\n🎯 NEXT STEPS:');
        console.log('   1. Test Events & Places in iOS app');
        console.log('   2. Update UI to use new Firebase data');
        console.log('   3. Remove old Adalo-dependent code');
        console.log('   4. Archive old data when confident');
        
    } catch (error) {
        console.error('💥 Fatal error:', error);
        process.exit(1);
    }
}

// Execute if run directly
if (require.main === module) {
    main().catch(console.error);
}

module.exports = { migrateEvents, migratePlaces }; 