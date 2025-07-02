// Quick script to test Firebase approach tips data
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/service-account-key.json'); // You'll need this file
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkApproachTips() {
    console.log('🔍 Checking Firebase data for approach tips...');
    
    try {
        const snapshot = await db.collection('users')
            .where('firstName', '!=', '')
            .limit(20)
            .get();
        
        if (snapshot.empty) {
            console.log('❌ No users found');
            return;
        }
        
        console.log(`📋 Found ${snapshot.size} users`);
        
        let usersWithTips = 0;
        let usersWithoutTips = 0;
        
        snapshot.forEach(doc => {
            const data = doc.data();
            const firstName = data.firstName || 'Unknown';
            const howToApproachMe = data.howToApproachMe;
            
            if (howToApproachMe && howToApproachMe.trim() !== '') {
                usersWithTips++;
                console.log(`✅ ${firstName} HAS tip: "${howToApproachMe}"`);
            } else {
                usersWithoutTips++;
                console.log(`❌ ${firstName} NO tip (raw: ${JSON.stringify(howToApproachMe)})`);
            }
            
            // Show all fields for first 3 users
            if (usersWithTips + usersWithoutTips <= 3) {
                console.log(`📋 ${firstName} fields:`, Object.keys(data).sort());
            }
        });
        
        console.log('\n📊 SUMMARY:');
        console.log(`  - Total users: ${snapshot.size}`);
        console.log(`  - Users WITH approach tips: ${usersWithTips}`);
        console.log(`  - Users WITHOUT approach tips: ${usersWithoutTips}`);
        console.log(`  - Percentage with tips: ${(usersWithTips / snapshot.size * 100).toFixed(1)}%`);
        
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
    
    process.exit(0);
}

checkApproachTips(); 