module.exports = {
  // Firebase project configuration
  firebase: {
    projectId: 'shift-12948',
    storageBucket: 'shift-12948.appspot.com' // Add this if different from projectId
  },
  
  // Adalo configuration
  adalo: {
    // Possible base URLs for Adalo images - the script will try these in order
    baseUrls: [
      'https://proton-uploads-production.s3.amazonaws.com/', // Your discovered URL pattern!
      '', // Try the URL as-is first
      'https://cdn.adalo.com/uploads/',
      'https://adalo-app-files.s3.amazonaws.com/',
      'https://shift-12948.adalo.app/uploads/',
      'https://uploads.adalo.com/'
    ],
    
    // If you need authentication headers for Adalo images
    headers: {
      // 'Authorization': 'Bearer YOUR_TOKEN_HERE',
      // 'X-API-Key': 'YOUR_API_KEY_HERE'
    }
  },
  
  // File paths
  files: {
    usersCSV: './data/Users.csv',
    eventsCSV: './data/Events.csv',
    placesCSV: './data/Places.csv',
    tempDirectory: './temp_images'
  },
  
  // CSV field mappings
  csvFields: {
    users: {
      idField: ' ID', // Note the space before ID
      imageField: 'Photo',
      emailField: 'Email'
    },
    events: {
      idField: ' ID',
      imageField: 'Image',
      nameField: 'Event Name'
    },
    places: {
      idField: ' ID',
      imageField: 'Place Image',
      nameField: 'Place Name'
    }
  },
  
  // Firebase Storage paths
  storagePaths: {
    users: 'profile_images',
    events: 'event_images',
    places: 'place_images'
  },
  
  // Firestore collections and field names
  firestore: {
    users: {
      collection: 'users',
      photoField: 'profilePhoto',
      queryField: 'email' // Field to query by when updating
    },
    events: {
      collection: 'events',
      photoField: 'image'
    },
    places: {
      collection: 'places',
      photoField: 'placeImage'
    }
  },
  
  // Processing options
  options: {
    // Maximum number of concurrent downloads
    maxConcurrent: 5,
    
    // Timeout for image downloads (in milliseconds)
    downloadTimeout: 30000,
    
    // Whether to skip images that already exist in Firebase Storage
    skipExisting: false,
    
    // Whether to make uploaded images publicly accessible
    makePublic: true,
    
    // Whether to clean up temporary files after processing
    cleanupTemp: true,
    
    // Log level: 'error', 'warn', 'info', 'verbose'
    logLevel: 'info'
  },
  
  // Default file extensions and content types
  contentTypes: {
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.tiff': 'image/tiff',
    '.heic': 'image/heic',
    '.bmp': 'image/bmp'
  }
}; 