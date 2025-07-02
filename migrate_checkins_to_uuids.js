const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin
const serviceAccount = require('./firebase-admin-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateCheckInsToUUIDs() {
  console.log('🔄 Starting check-in migration from Adalo IDs to UUIDs...');
  
  // Load the user mapping
  const userMapping = JSON.parse(fs.readFileSync('./firebase_migration_data/migrated_users.json', 'utf8'));
  
  // Create a map: adaloId -> uuid
  const adaloToUuidMap = {};
  userMapping.forEach(user => {
    adaloToUuidMap[user.originalAdaloId] = user.uuid;
  });
  
  console.log(`📊 Loaded mapping for ${Object.keys(adaloToUuidMap).length} users`);
  
  let placesUpdated = 0;
  let eventsUpdated = 0;
  let totalUsersConverted = 0;
  
  // Migrate Places
  console.log('\n🏢 Migrating Places...');
  const placesSnapshot = await db.collection('places').where('Users', '!=', null).get();
  
  for (const doc of placesSnapshot.docs) {
    const data = doc.data();
    const oldUsers = data.Users || [];
    
    if (oldUsers.length === 0) continue;
    
    // Convert Adalo IDs to UUIDs
    const newUsers = oldUsers.map(adaloId => {
      const uuid = adaloToUuidMap[adaloId];
      if (uuid) {
        totalUsersConverted++;
        return uuid;
      } else {
        console.log(`⚠️  No UUID found for Adalo ID ${adaloId} in place ${doc.id}`);
        return null;
      }
    }).filter(Boolean);
    
    if (newUsers.length > 0) {
      await doc.ref.update({ Users: newUsers });
      placesUpdated++;
      console.log(`✅ Place ${doc.id}: ${oldUsers.length} → ${newUsers.length} users`);
    }
  }
  
  // Migrate Events  
  console.log('\n🎉 Migrating Events...');
  const eventsSnapshot = await db.collection('events').where('Users', '!=', null).get();
  
  for (const doc of eventsSnapshot.docs) {
    const data = doc.data();
    const oldUsers = data.Users || [];
    
    if (oldUsers.length === 0) continue;
    
    // Convert Adalo IDs to UUIDs
    const newUsers = oldUsers.map(adaloId => {
      const uuid = adaloToUuidMap[adaloId];
      if (uuid) {
        totalUsersConverted++;
        return uuid;
      } else {
        console.log(`⚠️  No UUID found for Adalo ID ${adaloId} in event ${doc.id}`);
        return null;
      }
    }).filter(Boolean);
    
    if (newUsers.length > 0) {
      await doc.ref.update({ Users: newUsers });
      eventsUpdated++;
      console.log(`✅ Event ${doc.id}: ${oldUsers.length} → ${newUsers.length} users`);
    }
  }
  
  console.log('\n🎯 Migration Complete!');
  console.log(`📊 Summary:`);
  console.log(`   • Places updated: ${placesUpdated}`);
  console.log(`   • Events updated: ${eventsUpdated}`);
  console.log(`   • Total user references converted: ${totalUsersConverted}`);
  
  // Save migration summary
  const summary = {
    migrationDate: new Date().toISOString(),
    placesUpdated,
    eventsUpdated,
    totalUsersConverted,
    adaloToUuidMapSize: Object.keys(adaloToUuidMap).length
  };
  
  fs.writeFileSync('./firebase_migration_data/checkin_migration_summary.json', JSON.stringify(summary, null, 2));
  console.log('💾 Migration summary saved to checkin_migration_summary.json');
}

// Run migration
migrateCheckInsToUUIDs()
  .then(() => {
    console.log('✅ Check-in migration completed successfully!');
    process.exit(0);
  })
  .catch(error => {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }); 