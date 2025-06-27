# Shift App - Image Download & Upload Guide

This guide explains how to download images from your Adalo app and upload them to Firebase Storage for use in your Shift app.

## Overview

When you export data from Adalo, the CSV files contain image metadata but not the actual image files. This process will:

1. **Extract image URLs** from your Adalo CSV exports
2. **Download images** from Adalo's servers
3. **Upload images** to Firebase Storage
4. **Update Firestore** documents with new Firebase Storage URLs

## Prerequisites

- Node.js installed on your system
- Firebase Admin SDK credentials configured
- Adalo CSV exports in the `data/` folder:
  - `Users.csv`
  - `Events.csv` 
  - `Places.csv`

## Quick Start

### 1. Test Image Access First

Before running the full download process, test if your Adalo images are accessible:

```bash
npm run test-images
```

This will:
- Test a few sample images from each CSV file
- Try different URL formats to find the correct Adalo image URLs
- Show you which images are accessible and which aren't

### 2. Run the Full Download Process

Once you've confirmed images are accessible:

```bash
npm run download-images
```

This will process all images from all three CSV files and upload them to Firebase Storage.

## Configuration

You can customize the process by editing `image_config.js`:

### Firebase Settings
```javascript
firebase: {
  projectId: 'shift-12948',
  storageBucket: 'shift-12948.appspot.com'
}
```

### Adalo URLs
If the test script doesn't find working URLs, you may need to adjust the base URLs:
```javascript
adalo: {
  baseUrls: [
    '', // Try URL as-is
    'https://cdn.adalo.com/uploads/',
    'https://your-app.adalo.app/uploads/', // Replace with your app
    // Add more URL patterns as needed
  ]
}
```

### Authentication
If your Adalo images require authentication:
```javascript
adalo: {
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN_HERE',
    'X-API-Key': 'YOUR_API_KEY_HERE'
  }
}
```

## Process Details

### What Gets Downloaded

**User Photos:**
- Source: `Photo` field in `Users.csv`
- Destination: `profile_images/{userId}/filename.ext`
- Firestore field: `profilePhoto`

**Event Images:**
- Source: `Image` field in `Events.csv`
- Destination: `event_images/{eventId}/filename.ext`
- Firestore field: `image`

**Place Images:**
- Source: `Place Image` field in `Places.csv`
- Destination: `place_images/{placeId}/filename.ext`
- Firestore field: `placeImage`

### Image URL Structure

Your CSV files contain JSON-like image data:
```javascript
{
  'url': 'c13bd765ad60e9e23edbfd9e4f606a1420c86ef2999dd6504cd70f5588f8a439.jpeg',
  'size': 232685,
  'width': 714,
  'height': 1062,
  'filename': 'media.jpeg'
}
```

The script extracts the `url` field and tries different base URLs to find the accessible image.

## Troubleshooting

### Common Issues

**1. Images Not Accessible**
```
❌ FAILED: https://cdn.adalo.com/uploads/image.jpg
```
- **Solution:** Check your Adalo app's privacy settings
- **Try:** Adding authentication headers in `image_config.js`
- **Check:** If your Adalo app requires login to view images

**2. CSV Parse Errors**
```
⚠️ Could not parse image data: {'url':'...
```
- **Solution:** CSV export may have formatting issues
- **Try:** Re-exporting data from Adalo
- **Check:** Open CSV in text editor to verify format

**3. Firebase Upload Errors**
```
❌ Failed to upload: Permission denied
```
- **Solution:** Check Firebase Storage rules
- **Verify:** Your service account has Storage Admin permissions
- **Update:** `firestore.rules` to allow image uploads

**4. Firestore Update Errors**
```
❌ No document found for user: user@example.com
```
- **Solution:** Ensure you've run the data migration scripts first
- **Check:** User exists in Firestore with correct email

### Testing Individual Steps

**Test CSV parsing only:**
```javascript
// In test_image_access.js, comment out the HTTP requests
// to just see extracted URLs
```

**Test download only (no Firebase upload):**
```javascript
// In download_and_upload_images.js, comment out:
// - uploadToFirebase() calls
// - Firestore update calls
```

**Test Firebase upload only:**
```javascript
// Manually place test images in temp_images/
// Run uploadToFirebase() function
```

## Advanced Usage

### Custom URL Patterns

If your Adalo images use a different URL structure, modify the `extractImageUrl` function:

```javascript
function extractImageUrl(imageDataString) {
  // Your custom URL logic here
  return constructedUrl;
}
```

### Batch Processing

For large datasets, you might want to process in batches:

```javascript
// Modify the config
options: {
  maxConcurrent: 3, // Reduce concurrent downloads
  downloadTimeout: 60000 // Increase timeout
}
```

### Selective Processing

To process only specific types of images, comment out the unwanted functions in `main()`:

```javascript
async function main() {
  // await processUserImages();     // Skip users
  await processEventImages();       // Only events
  // await processPlaceImages();    // Skip places
}
```

## File Structure After Processing

```
Firebase Storage:
├── profile_images/
│   ├── 829/
│   │   └── c13bd765...jpeg
│   └── 828/
│       └── 191358ef...png
├── event_images/
│   ├── 219/
│   │   └── 79e95c91...jpeg
│   └── 218/
│       └── 5b738a1f...jpeg
└── place_images/
    ├── 80/
    │   └── fd989115...jpeg
    └── 79/
        └── image.jpg
```

## Security Notes

- Images are made publicly accessible by default
- Consider your privacy requirements before running
- Adalo images may contain sensitive user data
- Test with a small subset first

## Support

If you encounter issues:

1. **Check the console output** for specific error messages
2. **Run the test script first** to identify URL problems
3. **Verify your Firebase permissions** and configuration
4. **Check Adalo app settings** for image privacy/access rules

## Next Steps

After successful image migration:

1. **Update your iOS app** to use the new Firebase Storage URLs
2. **Test image loading** in your app
3. **Clean up temporary files** (done automatically)
4. **Update any hardcoded Adalo URLs** in your app code

---

**Need help?** Check the console output for detailed error messages and troubleshooting steps. 