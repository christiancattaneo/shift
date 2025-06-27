const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json'); // You'll need to download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Helper function to upload CSV data to Firestore
async function uploadCSVToFirestore(csvFilePath, collectionName, dataTransformer) {
  return new Promise((resolve, reject) => {
    const results = [];
    
    fs.createReadStream(csvFilePath)
      .pipe(csv())
      .on('data', (data) => {
        results.push(dataTransformer(data));
      })
      .on('end', async () => {
        console.log(`Processing ${results.length} records for ${collectionName}...`);
        
        const batch = db.batch();
        
        for (const item of results) {
          const docRef = db.collection(collectionName).doc();
          batch.set(docRef, {
            ...item,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        try {
          await batch.commit();
          console.log(`✅ Successfully uploaded ${results.length} records to ${collectionName}`);
          resolve();
        } catch (error) {
          console.error(`❌ Error uploading to ${collectionName}:`, error);
          reject(error);
        }
      })
      .on('error', reject);
  });
}

// Data transformers for each CSV type
const userTransformer = (data) => ({
  email: data.email || '',
  firstName: data.firstName || data.first_name || '',
  fullName: data.fullName || data.full_name || '',
  username: data.username || '',
  profilePhoto: data.profilePhoto || data.profile_photo || '',
  gender: data.gender || '',
  attractedTo: data.attractedTo || data.attracted_to || '',
  age: data.age ? parseInt(data.age) : null,
  city: data.city || '',
  howToApproachMe: data.howToApproachMe || data.how_to_approach_me || '',
  isEventCreator: data.isEventCreator === 'true' || data.is_event_creator === 'true',
  isEventAttendee: data.isEventAttendee === 'true' || data.is_event_attendee === 'true',
  instagramHandle: data.instagramHandle || data.instagram_handle || '',
  subscribed: data.subscribed === 'true'
});

const eventTransformer = (data) => ({
  eventName: data.eventName || data.event_name || '',
  venueName: data.venueName || data.venue_name || '',
  eventLocation: data.eventLocation || data.event_location || '',
  eventStartTime: data.eventStartTime || data.event_start_time || '',
  eventEndTime: data.eventEndTime || data.event_end_time || '',
  image: data.image || '',
  isEventFree: data.isEventFree === 'true' || data.is_event_free === 'true',
  eventCategory: data.eventCategory || data.event_category || '',
  eventDate: data.eventDate || data.event_date || '',
  place: data.place || ''
});

const placeTransformer = (data) => ({
  placeName: data.placeName || data.place_name || '',
  placeLocation: data.placeLocation || data.place_location || '',
  placeImage: data.placeImage || data.place_image || '',
  isPlaceFree: data.isPlaceFree === 'true' || data.is_place_free === 'true'
});

async function uploadAllData() {
  try {
    const dataFolder = '/Users/christiancattaneo/Desktop/data';
    
    // Check if files exist and upload them
    const usersFile = path.join(dataFolder, 'Users.csv');
    const eventsFile = path.join(dataFolder, 'Events.csv');
    const placesFile = path.join(dataFolder, 'Places.csv');
    
    if (fs.existsSync(usersFile)) {
      console.log('📤 Uploading Users data...');
      await uploadCSVToFirestore(usersFile, 'users', userTransformer);
    } else {
      console.log('⚠️  Users.csv not found');
    }
    
    if (fs.existsSync(eventsFile)) {
      console.log('📤 Uploading Events data...');
      await uploadCSVToFirestore(eventsFile, 'events', eventTransformer);
    } else {
      console.log('⚠️  Events.csv not found');
    }
    
    if (fs.existsSync(placesFile)) {
      console.log('📤 Uploading Places data...');
      await uploadCSVToFirestore(placesFile, 'places', placeTransformer);
    } else {
      console.log('⚠️  Places.csv not found');
    }
    
    console.log('🎉 All data uploaded successfully!');
    process.exit(0);
    
  } catch (error) {
    console.error('💥 Error uploading data:', error);
    process.exit(1);
  }
}

// Run the upload
uploadAllData(); 