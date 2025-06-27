# Shift iOS App - Adalo Database Integration Setup Guide

This guide will help you connect your Shift iOS app to your Adalo database.

## Prerequisites

- An Adalo account with a created app
- Xcode installed on your Mac
- Basic understanding of iOS development

## Step 1: Get Your Adalo API Credentials

1. **Log into Adalo Dashboard**
   - Go to [https://app.adalo.com](https://app.adalo.com)
   - Sign in to your account

2. **Access Your App**
   - Navigate to your Shift app in the dashboard
   - Note the App ID from your browser URL (e.g., `https://app.adalo.com/apps/YOUR_APP_ID_HERE`)

3. **Generate API Key**
   - In your app dashboard, click the settings gear icon (⚙️) in the left navigation
   - Expand "App Access" section  
   - Click "Generate API Key"
   - Copy the generated API key (keep it secure!)

## Step 2: Configure Your iOS App

1. **Update Configuration File**
   - Open `shift/AdaloConfig.swift` in Xcode
   - Replace `YOUR_ADALO_API_KEY_HERE` with your actual API key
   - Replace `YOUR_ADALO_APP_ID_HERE` with your actual App ID

```swift
struct AdaloConfiguration {
    static let apiKey = "your_actual_api_key_here"
    static let appID = "your_actual_app_id_here"
    // ... rest of the configuration
}
```

## Step 3: Set Up Your Adalo Database Collections

Create the following collections in your Adalo app with the exact field names and types:

### 1. Users Collection
| Field Name | Type | Required |
|------------|------|----------|
| Email | Email | Yes |
| First Name | Text | Yes |
| Last Name | Text | No |
| Profile Photo | Image | No |

### 2. Members Collection
| Field Name | Type | Required |
|------------|------|----------|
| First Name | Text | Yes |
| Age | Number | No |
| City | Text | No |
| Attracted To | Text | No |
| Approach Tip | Text | No |
| Instagram Handle | Text | No |
| Profile Image | Image | No |
| Is Active | True/False | No |

### 3. Events Collection
| Field Name | Type | Required |
|------------|------|----------|
| Name | Text | Yes |
| Address | Text | No |
| Description | Text | No |
| Latitude | Number | No |
| Longitude | Number | No |
| Is Active | True/False | No |

### 4. Conversations Collection
| Field Name | Type | Required |
|------------|------|----------|
| Participant One ID | Number | Yes |
| Participant Two ID | Number | Yes |
| Last Message | Text | No |
| Last Message At | Date & Time | No |
| Is Read | True/False | No |

### 5. Messages Collection
| Field Name | Type | Required |
|------------|------|----------|
| Conversation ID | Number | Yes |
| Sender ID | Number | Yes |
| Message Text | Text | Yes |
| Sent At | Date & Time | No |

### 6. Check_Ins Collection
| Field Name | Type | Required |
|------------|------|----------|
| User ID | Number | Yes |
| Event ID | Number | Yes |
| Checked In At | Date & Time | No |
| Checked Out At | Date & Time | No |
| Is Active | True/False | No |

## Step 4: Set Collection Permissions

For each collection created above:

1. Go to Database tab in your Adalo app
2. Click on each collection
3. Click the "Permissions" tab
4. Set the appropriate permissions:
   - **Create**: Allow logged-in users
   - **Read**: Allow logged-in users  
   - **Update**: Allow logged-in users (for their own records)
   - **Delete**: Allow logged-in users (for their own records)

## Step 5: Test Your Connection

1. **Build and Run**
   - Open your iOS project in Xcode
   - Build and run the app on simulator or device

2. **Test Authentication**
   - Try signing up with a test email
   - Check if the user appears in your Adalo Users collection
   - Try logging in with the same credentials

3. **Verify Data Flow**
   - Check that members data loads in the Members tab
   - Try creating test data in Adalo and see if it appears in the app

## Step 6: Add Sample Data (Optional)

To test the app functionality, add some sample data to your Adalo collections:

### Sample Members
```
Member 1:
- First Name: "Alex"
- Age: 25
- City: "Austin, TX"
- Attracted To: "Female"
- Approach Tip: "Ask about my favorite coffee shops"
- Is Active: true

Member 2:
- First Name: "Jordan"
- Age: 28
- City: "Austin, TX" 
- Attracted To: "Male"
- Approach Tip: "Let's talk about hiking trails"
- Is Active: true
```

### Sample Events
```
Event 1:
- Name: "Coffee & Code"
- Address: "123 Main St, Austin, TX"
- Description: "Weekly meetup for developers"
- Is Active: true

Event 2:
- Name: "Austin Food Truck Friday"
- Address: "Rainey Street, Austin, TX"
- Description: "Best food trucks in town"
- Is Active: true
```

## Troubleshooting

### Common Issues

1. **"Invalid API Key" Error**
   - Double-check your API key in `AdaloConfig.swift`
   - Make sure there are no extra spaces or characters
   - Regenerate the API key in Adalo if needed

2. **"Collection Not Found" Error**
   - Verify collection names match exactly (case-sensitive)
   - Check that collections are created in your Adalo app
   - Ensure field names match exactly as specified above

3. **"Permission Denied" Error**
   - Check collection permissions in Adalo
   - Make sure users can create/read/update records
   - Verify user authentication is working

4. **No Data Loading**
   - Check your internet connection
   - Verify API credentials are correct
   - Look at Xcode console for error messages
   - Add some test data to your Adalo collections

### Debug Tips

1. **Enable Debug Logging**
   - Check Xcode console for error messages
   - Look for network request failures
   - Verify API responses

2. **Test API Directly**
   - Use Postman or curl to test your Adalo API
   - Verify endpoints are working outside the app
   - Check data format matches expectations

3. **Adalo Dashboard**
   - Monitor your app usage in Adalo dashboard
   - Check if API calls are being received
   - Verify data is being created/updated

## Rate Limiting

- Adalo API allows 5 requests per second
- The app includes rate limiting handling
- If you hit limits, requests will automatically retry

## Next Steps

Once your app is connected to Adalo:

1. **Customize UI**: Modify the app interface to match your brand
2. **Add Features**: Implement additional functionality like push notifications
3. **Deploy**: Prepare your app for App Store submission
4. **Scale**: Consider upgrading your Adalo plan for production use

## Support

If you encounter issues:

1. Check the Adalo documentation: [https://help.adalo.com](https://help.adalo.com)
2. Review the iOS code comments for implementation details
3. Test with the Adalo API documentation examples
4. Reach out to Adalo support for API-specific issues

---

**Important**: Keep your API key secure and never commit it to version control in production apps. Consider using environment variables or secure storage for production deployments. 