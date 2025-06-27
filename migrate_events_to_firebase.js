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

async function migrateEventsToFirebase() {
  const results = [];
  const eventsFile = path.join(__dirname, 'data/Events.csv');
  
  return new Promise((resolve, reject) => {
    fs.createReadStream(eventsFile)
      .pipe(csv())
      .on('data', (data) => {
        results.push(data);
      })
      .on('end', async () => {
        console.log(`🔄 Processing ${results.length} events for migration...`);
        
        let successCount = 0;
        let errorCount = 0;
        
        for (const row of results) {
          try {
            // Skip if no event name
            if (!row['Event Name'] || row['Event Name'].trim() === '') {
              console.log('⚠️  Skipping event without name');
              continue;
            }
            
            // Parse image data if exists
            let imageData = null;
            if (row['Image'] && row['Image'].trim() !== '') {
              try {
                // Clean up the image string and parse JSON
                const cleanImageString = row['Image'].replace(/'/g, '"');
                imageData = JSON.parse(cleanImageString);
              } catch (imageError) {
                console.log(`⚠️  Could not parse image data for event: ${row['Event Name']}`);
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
            
            // Create event object
            const eventData = {
              id: row[' ID'] || row['ID'], // Handle potential leading space
              eventName: row['Event Name'],
              venueName: row['Venue Name'] || null,
              eventLocation: row['Event Location'] || null,
              eventStartTime: parseDate(row['Event Start Time']),
              eventEndTime: parseDate(row['Event End Time']),
              image: imageData,
              isEventFree: row['Is Event Free'] === 'TRUE' || row['Is Event Free'] === 'true',
              eventCategory: row['Event Category'] || null,
              eventDate: parseDate(row['Event DATE']),
              place: row['Place'] || null,
              createdAt: parseDate(row['Created']) || admin.firestore.Timestamp.now(),
              updatedAt: parseDate(row['Updated']) || admin.firestore.Timestamp.now(),
              
              // Additional fields for Firebase structure
              isActive: true,
              attendeeCount: 0,
              checkedInUsers: []
            };
            
            // Use the original ID as document ID
            const docId = eventData.id.toString();
            
            // Create event document in Firestore
            await db.collection('events').doc(docId).set(eventData);
            
            console.log(`✅ Created event: ${eventData.eventName}`);
            successCount++;
            
          } catch (error) {
            console.log(`❌ Error migrating event ${row['Event Name']}: ${error.message}`);
            errorCount++;
          }
        }
        
        console.log('\n🎉 Events Migration Complete!');
        console.log(`✅ Successfully migrated: ${successCount} events`);
        console.log(`❌ Errors: ${errorCount} events`);
        console.log('\n📱 Events are now available in Firebase!');
        
        resolve();
      })
      .on('error', (error) => {
        console.log('❌ Error reading CSV file:', error);
        reject(error);
      });
  });
}

// Run the migration
migrateEventsToFirebase()
  .then(() => {
    console.log('Migration completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  }); 