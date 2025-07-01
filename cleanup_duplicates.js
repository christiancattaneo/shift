const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin (using default credentials)
admin.initializeApp({
  projectId: 'shift-12948',
  databaseURL: 'https://shift-12948-default-rtdb.firebaseio.com/',
  storageBucket: 'shift-12948.firebasestorage.app'
});

const db = admin.firestore();

async function analyzeAndCleanupDuplicates() {
  console.log('🔍 Analyzing user duplicates...');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} total user documents`);
    
    // Track duplicates by email and firstName
    const duplicatesByEmail = new Map();
    const duplicatesByName = new Map();
    const allUsers = [];
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      const user = {
        id: doc.id,
        email: data.email,
        firstName: data.firstName,
        fullName: data.fullName,
        uid: data.uid,
        createdAt: data.createdAt,
        ...data
      };
      allUsers.push(user);
      
      // Track by email
      if (user.email) {
        const email = user.email.toLowerCase();
        if (!duplicatesByEmail.has(email)) {
          duplicatesByEmail.set(email, []);
        }
        duplicatesByEmail.get(email).push(user);
      }
      
      // Track by firstName (for debugging)
      if (user.firstName) {
        const name = user.firstName.toLowerCase();
        if (!duplicatesByName.has(name)) {
          duplicatesByName.set(name, []);
        }
        duplicatesByName.get(name).push(user);
      }
    });
    
    // Find email duplicates
    const emailDuplicates = [];
    duplicatesByEmail.forEach((users, email) => {
      if (users.length > 1) {
        emailDuplicates.push({ email, users });
      }
    });
    
    // Find name duplicates
    const nameDuplicates = [];
    duplicatesByName.forEach((users, name) => {
      if (users.length > 1) {
        nameDuplicates.push({ name, users });
      }
    });
    
    console.log(`📧 Found ${emailDuplicates.length} email duplicates`);
    console.log(`👤 Found ${nameDuplicates.length} name duplicates`);
    
    // Log email duplicates
    console.log('\n📧 EMAIL DUPLICATES:');
    emailDuplicates.forEach(({ email, users }) => {
      console.log(`\n📧 ${email} (${users.length} copies):`);
      users.forEach((user, index) => {
        console.log(`  ${index + 1}. ID: ${user.id}`);
        console.log(`     Created: ${user.createdAt ? new Date(user.createdAt.seconds * 1000).toISOString() : 'unknown'}`);
        console.log(`     UID: ${user.uid || 'none'}`);
        console.log(`     Name: ${user.firstName} ${user.fullName || ''}`);
      });
    });
    
    // Log some name duplicates (first 5)
    console.log('\n👤 NAME DUPLICATES (first 5):');
    nameDuplicates.slice(0, 5).forEach(({ name, users }) => {
      console.log(`\n👤 ${name} (${users.length} copies):`);
      users.forEach((user, index) => {
        console.log(`  ${index + 1}. ID: ${user.id}, Email: ${user.email || 'none'}`);
      });
    });
    
    // Save analysis to file
    const analysis = {
      totalUsers: allUsers.length,
      emailDuplicates: emailDuplicates.length,
      nameDuplicates: nameDuplicates.length,
      duplicateDetails: {
        byEmail: emailDuplicates,
        byName: nameDuplicates.slice(0, 10) // Save first 10 name duplicates
      }
    };
    
    fs.writeFileSync('duplicate_analysis.json', JSON.stringify(analysis, null, 2));
    console.log('\n✅ Analysis saved to duplicate_analysis.json');
    
    // Ask for confirmation before cleanup
    if (emailDuplicates.length > 0) {
      console.log('\n⚠️  DUPLICATE CLEANUP NEEDED');
      console.log('Run with --cleanup flag to remove duplicates');
      console.log('Example: node cleanup_duplicates.js --cleanup');
    } else {
      console.log('\n✅ No email duplicates found - database is clean!');
    }
    
  } catch (error) {
    console.error('❌ Error analyzing duplicates:', error);
  }
}

async function cleanupDuplicates() {
  console.log('🧹 Starting duplicate cleanup...');
  
  try {
    // Read analysis
    if (!fs.existsSync('duplicate_analysis.json')) {
      console.log('❌ No analysis found. Run without --cleanup first.');
      return;
    }
    
    const analysis = JSON.parse(fs.readFileSync('duplicate_analysis.json', 'utf8'));
    const emailDuplicates = analysis.duplicateDetails.byEmail;
    
    if (emailDuplicates.length === 0) {
      console.log('✅ No email duplicates to clean up!');
      return;
    }
    
    console.log(`🧹 Cleaning up ${emailDuplicates.length} email duplicate groups...`);
    
    const batch = db.batch();
    let deletedCount = 0;
    
    for (const { email, users } of emailDuplicates) {
      // Sort by creation date - keep the oldest (most likely original)
      const sortedUsers = users.sort((a, b) => {
        const aTime = a.createdAt ? a.createdAt.seconds : 0;
        const bTime = b.createdAt ? b.createdAt.seconds : 0;
        return aTime - bTime;
      });
      
      const keepUser = sortedUsers[0];
      const deleteUsers = sortedUsers.slice(1);
      
      console.log(`📧 ${email}: keeping ${keepUser.id}, deleting ${deleteUsers.length} duplicates`);
      
      for (const user of deleteUsers) {
        batch.delete(db.collection('users').doc(user.id));
        deletedCount++;
      }
    }
    
    if (deletedCount > 0) {
      console.log(`🗑️  Deleting ${deletedCount} duplicate users...`);
      await batch.commit();
      console.log('✅ Cleanup complete!');
    } else {
      console.log('✅ No users to delete');
    }
    
  } catch (error) {
    console.error('❌ Error cleaning up duplicates:', error);
  }
}

// Main execution
const args = process.argv.slice(2);
if (args.includes('--cleanup')) {
  cleanupDuplicates()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
} else {
  analyzeAndCleanupDuplicates()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
} 