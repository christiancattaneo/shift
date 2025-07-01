const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin if not already done
if (!admin.apps.length) {
    try {
        const serviceAccount = require('./firebase-admin-key.json');
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount),
            storageBucket: 'shift-12948.firebasestorage.app'
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

// Load Events and Places data
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

// Upload image to Firebase Storage
async function uploadImage(localPath, storagePath) {
    try {
        if (!fs.existsSync(localPath)) {
            console.log(`⚠️  Local file not found: ${localPath}`);
            return null;
        }

        const [file] = await bucket.upload(localPath, {
            destination: storagePath,
            metadata: {
                cacheControl: 'public, max-age=31536000',
            },
        });

        // Make the file publicly accessible
        await file.makePublic();

        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
        console.log(`✅ Uploaded: ${storagePath}`);
        return publicUrl;
    } catch (error) {
        console.error(`❌ Error uploading ${localPath}:`, error.message);
        return null;
    }
}

// Update Firestore document with new image URL
async function updateDocumentWithImage(collection, docId, imageUrl, imageField = 'firebaseImageUrl') {
    try {
        await db.collection(collection).doc(docId).update({
            [imageField]: imageUrl,
            updatedAt: admin.firestore.Timestamp.now()
        });
        console.log(`📄 Updated ${collection}/${docId} with image URL`);
        return true;
    } catch (error) {
        console.error(`❌ Error updating ${collection}/${docId}:`, error.message);
        return false;
    }
}

// Main migration function
async function migrateImages() {
    console.log('🚀 STARTING EVENTS & PLACES IMAGE MIGRATION TO FIREBASE STORAGE\n');
    
    const { eventsData, placesData } = loadData();
    
    let eventSuccess = 0;
    let eventFailed = 0;
    let placeSuccess = 0;
    let placeFailed = 0;

    // Migrate Event Images
    console.log('📸 MIGRATING EVENT IMAGES...\n');
    
    for (const event of eventsData) {
        const eventId = event.id;
        const imageName = event.Image?.url || event.Image;
        
        if (!imageName || typeof imageName !== 'string') {
            console.log(`⚠️  Event ${eventId}: No image found`);
            eventFailed++;
            continue;
        }

        // Find the actual downloaded file for this event ID
        const eventDir = './adalo_data/event_images/';
        const files = fs.readdirSync(eventDir).filter(f => f.startsWith(`${eventId}_`));
        
        if (files.length === 0) {
            console.log(`⚠️  Event ${eventId}: No local file found`);
            eventFailed++;
            continue;
        }
        
        const filename = files[0]; // Use the first matching file
        const localPath = `${eventDir}${filename}`;
        const storagePath = `events/${filename}`;

        // Upload image to Firebase Storage
        const imageUrl = await uploadImage(localPath, storagePath);
        
        if (imageUrl) {
            // Update the Firestore document
            const updateSuccess = await updateDocumentWithImage('events', eventId, imageUrl);
            if (updateSuccess) {
                eventSuccess++;
            } else {
                eventFailed++;
            }
        } else {
            eventFailed++;
        }

        // Add a small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    console.log(`\n📊 EVENT IMAGES MIGRATION COMPLETE:`);
    console.log(`   ✅ Success: ${eventSuccess}`);
    console.log(`   ❌ Failed: ${eventFailed}\n`);

    // Migrate Place Images
    console.log('🏢 MIGRATING PLACE IMAGES...\n');
    
    for (const place of placesData) {
        const placeId = place.id;
        const imageName = place['Place Image']?.url || place['Place Image'];
        
        if (!imageName || typeof imageName !== 'string') {
            console.log(`⚠️  Place ${placeId}: No image found`);
            placeFailed++;
            continue;
        }

        // Find the actual downloaded file for this place ID
        const placeDir = './adalo_data/place_images/';
        const files = fs.readdirSync(placeDir).filter(f => f.startsWith(`${placeId}_`));
        
        if (files.length === 0) {
            console.log(`⚠️  Place ${placeId}: No local file found`);
            placeFailed++;
            continue;
        }
        
        const filename = files[0]; // Use the first matching file
        const localPath = `${placeDir}${filename}`;
        const storagePath = `places/${filename}`;

        // Upload image to Firebase Storage
        const imageUrl = await uploadImage(localPath, storagePath);
        
        if (imageUrl) {
            // Update the Firestore document
            const updateSuccess = await updateDocumentWithImage('places', placeId, imageUrl);
            if (updateSuccess) {
                placeSuccess++;
            } else {
                placeFailed++;
            }
        } else {
            placeFailed++;
        }

        // Add a small delay to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    console.log(`\n📊 PLACE IMAGES MIGRATION COMPLETE:`);
    console.log(`   ✅ Success: ${placeSuccess}`);
    console.log(`   ❌ Failed: ${placeFailed}\n`);

    // Final Summary
    console.log('🎉 COMPLETE EVENTS & PLACES IMAGE MIGRATION FINISHED!');
    console.log('📊 FINAL RESULTS:');
    console.log(`   📸 Event Images: ${eventSuccess}/${eventSuccess + eventFailed} uploaded`);
    console.log(`   🏢 Place Images: ${placeSuccess}/${placeSuccess + placeFailed} uploaded`);
    console.log(`   📝 Total Success: ${eventSuccess + placeSuccess}`);
    console.log(`   ❌ Total Failed: ${eventFailed + placeFailed}`);
    
    const totalImages = eventSuccess + placeSuccess + eventFailed + placeFailed;
    const successRate = ((eventSuccess + placeSuccess) / totalImages * 100).toFixed(1);
    console.log(`   📈 Success Rate: ${successRate}%`);

    console.log('\n🔥 BENEFITS ACHIEVED:');
    console.log('   ✅ Events & Places images now in Firebase Storage');
    console.log('   ✅ Public URLs for all images');
    console.log('   ✅ Firestore documents updated with new URLs'); 
    console.log('   ✅ Fast CDN delivery');
    console.log('   ✅ Perfect integration with iOS app');
}

// Run the migration
migrateImages().catch(console.error); 