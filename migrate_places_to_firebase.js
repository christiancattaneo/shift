const admin = require('firebase-admin');
const fs = require('fs');
const csv = require('csv-parser');
const path = require('path');

// Initialize Firebase Admin SDK using application default credentials
// This works with Firebase CLI authentication
admin.initializeApp({
  projectId: 'shift-12948'
});

const db = admin.firestore();

async function migratePlacesToFirebase() {
  const results = [];
  const placesFile = path.join(__dirname, 'data/Places.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(placesFile)
      .pipe(csv())
      .on('data', (data) => {
        results.push(data);
      })
      .on('end', async () => {
        console.log(`🔄 Processing ${results.length} places for migration...`);
        
        let successCount = 0;
        let errorCount = 0;
        
        for (const row of results) {
          try {
            // Skip if no place name
            if (!row['Place Name'] || row['Place Name'].trim() === '') {
              console.log('⚠️  Skipping place without name');
              continue;
            }
            
            // Parse image data if exists
            let imageData = null;
            if (row['Place Image'] && row['Place Image'].trim() !== '') {
              try {
                // Clean up the image string and parse JSON
                const cleanImageString = row['Place Image'].replace(/'/g, '"');
                imageData = JSON.parse(cleanImageString);
              } catch (imageError) {
                console.log(`⚠️  Could not parse image data for place: ${row['Place Name']}`);
                imageData = null;
              }
            }
            
            // Parse dates
            const parseDate = (dateString) => {
              if (!dateString || dateString.trim() === '') return null;
              try {
                return admin.firestore.Timestamp.fromDate(new Date(dateString));
              } catch {
                return null;
              }
            };
            
            // Create place object
            const placeData = {
              id: row[' ID'] || row['ID'], // Handle potential leading space
              placeName: row['Place Name'],
              placeLocation: row['Place Locatioon'] || row['Place Location'] || null, // Handle typo in CSV
              placeImage: imageData,
              isPlaceFree: row['is place free'] === 'TRUE' || row['is place free'] === 'true',
              createdAt: parseDate(row['Created']) || admin.firestore.Timestamp.now(),
              updatedAt: parseDate(row['Updated']) || admin.firestore.Timestamp.now(),
              
              // Additional fields for Firebase structure
              isActive: true,
              category: null, // Can be populated later
              rating: 0,
              checkedInCount: 0,
              description: null
            };
            
            // Use the original ID as document ID
            const docId = placeData.id.toString();
            
            // Create place document in Firestore
            await db.collection('places').doc(docId).set(placeData);
            
            console.log(`✅ Created place: ${placeData.placeName}`);
            successCount++;
            
          } catch (error) {
            console.log(`❌ Error migrating place ${row['Place Name']}: ${error.message}`);
            errorCount++;
          }
        }
        
        console.log('\n🎉 Places Migration Complete!');
        console.log(`✅ Successfully migrated: ${successCount} places`);
        console.log(`❌ Errors: ${errorCount} places`);
        console.log('\n📱 Places are now available in Firebase!');
        
        resolve();
      })
      .on('error', (error) => {
        console.log('❌ Error reading CSV file:', error);
        reject(error);
      });
  });
}

// Run the migration
migratePlacesToFirebase()
  .then(() => {
    console.log('Migration completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  }); 