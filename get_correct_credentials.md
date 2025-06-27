# 🔑 How to Get Your Correct Adalo API Credentials

## 🚨 Current Issue
Your API key `5rnjxksuttzdf4vguio61vgqq` is returning **"Access token / app mismatch"** errors, which means either:
- The API key is invalid/expired
- The App ID `a03b07ee-0cee-4d06-82bb-75e4f6193332` is wrong
- The API key belongs to a different app

## 📍 Step-by-Step Guide to Get Correct Credentials

### Step 1: Open Your Adalo Dashboard
1. Go to [https://app.adalo.com](https://app.adalo.com)
2. Sign in with: `info@aretihouse.com` / `BigMac1158`

### Step 2: Select Your Shift App
1. Look for your **"Shift"** app in the dashboard
2. **IMPORTANT**: Make sure this app shows your **Users collection with 651 records**
3. Click on the Shift app to open it

### Step 3: Navigate to API Settings
1. In your Shift app, go to **"Settings"** (usually in the left sidebar or top menu)
2. Look for **"API & Integrations"** or **"Database"** or **"External API"**
3. Click on that section

### Step 4: Copy the Correct Credentials
Look for these fields and copy them **exactly**:

```
API Key: [Copy this - should be different from current one]
App ID: [Copy this - might be called "Database ID" or "Application ID"]
Base URL: [Usually https://api.adalo.com/v0 but verify]
```

### Step 5: Alternative Locations to Check
If you can't find API settings in Settings, try:
- **"Database"** tab/menu
- **"Actions"** → **"External API"**
- **"Integrations"** menu
- Look for **"API Documentation"** link next to your collections
- Right-click on your **Users collection** → **"API Documentation"**

## 🧪 Quick Test Script
Once you have the new credentials, update this test:

```bash
# Replace with your NEW credentials
API_KEY="YOUR_NEW_API_KEY_HERE"
APP_ID="YOUR_NEW_APP_ID_HERE"

# Test the connection
curl -H "Authorization: Bearer $API_KEY" \
     -H "Content-Type: application/json" \
     "https://api.adalo.com/v0/apps/$APP_ID/collections"
```

## 🎯 What We're Looking For
A successful response should show your collections including:
- **Users** (with 651 records)
- **Events** 
- **Places**

## 📞 Need Help?
If you can't find these settings:
1. **Take a screenshot** of your Adalo dashboard
2. **Check if there's an "API Documentation" button** next to your Users collection
3. **Look for any "Developer" or "Advanced" settings**

---
**Once you have the correct credentials, I'll update the iOS app and we can test the connection immediately!** 🚀 