const fs = require('fs');
const path = require('path');

// Helper to create Firebase Admin config from existing project info
function createFirebaseAdminConfig() {
  console.log('🔧 Firebase Admin SDK Setup Helper');
  console.log('');
  
  // Check if GoogleService-Info.plist exists
  const plistPath = './GoogleService-Info.plist';
  const serviceAccountPath = './firebase-admin-key.json';
  
  if (fs.existsSync(serviceAccountPath)) {
    console.log('✅ Firebase Admin key already exists: firebase-admin-key.json');
    return;
  }
  
  // We need to create a service account key
  console.log('🚨 You need to create a Firebase Admin SDK service account key');
  console.log('');
  console.log('📋 Steps to get your service account key:');
  console.log('');
  console.log('1. Go to: https://console.firebase.google.com/project/shift-12948/settings/serviceaccounts/adminsdk');
  console.log('2. Click "Generate new private key"');
  console.log('3. Download the JSON file');
  console.log('4. Rename it to: firebase-admin-key.json');
  console.log('5. Place it in this directory');
  console.log('');
  console.log('🔒 The file should look like this:');
  console.log(`{
  "type": "service_account",
  "project_id": "shift-12948",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\\n...\\n-----END PRIVATE KEY-----\\n",
  "client_email": "firebase-adminsdk-...@shift-12948.iam.gserviceaccount.com",
  "client_id": "...",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "..."
}`);
  console.log('');
  console.log('⚠️  NEVER commit this file to git - it contains secret keys!');
}

// Run the helper
createFirebaseAdminConfig(); 