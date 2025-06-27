# iOS Environment Configuration Guide

This guide explains how to properly manage environment variables and configuration for your Shift iOS app using **Xcode Configuration Files (.xcconfig)** - the recommended approach for iOS development.

## 🚨 **Why Not .env Files?**

Unlike web development, iOS apps don't use `.env` files because:
- **Security**: .env files can be easily extracted from app bundles
- **iOS Ecosystem**: Xcode has built-in configuration management
- **Code Signing**: iOS requires proper integration with Xcode's build system
- **App Store**: Better compliance with App Store security requirements

## 🛠 **Current Setup Structure**

```
Your Project/
├── Config-Debug.xcconfig      # Development environment settings
├── Config-Release.xcconfig    # Production environment settings  
├── shift/
│   ├── Info.plist            # Bridges xcconfig → Swift code
│   └── AdaloConfig.swift     # Reads from Info.plist
```

## 📝 **How It Works**

1. **`.xcconfig` files** store your environment variables
2. **`Info.plist`** bridges the values using `$(VARIABLE_NAME)` syntax
3. **`AdaloConfig.swift`** reads from Info.plist at runtime
4. **Xcode build configurations** automatically choose the right file

## 🔧 **Configuration Files**

### **Config-Debug.xcconfig** (Development)
```ini
// Development environment - automatically used for Debug builds
ADALO_API_KEY = your_dev_api_key_here
ADALO_APP_ID = your_dev_app_id_here
ENABLE_DEBUG_MENU = YES
ENABLE_LOGGING = YES
```

### **Config-Release.xcconfig** (Production)
```ini
// Production environment - automatically used for Release builds
ADALO_API_KEY = your_production_api_key_here
ADALO_APP_ID = your_production_app_id_here
ENABLE_DEBUG_MENU = NO
ENABLE_LOGGING = NO
```

## 🚀 **Setup Instructions**

### **Step 1: Update Your API Keys**

1. **For Development** - Edit `Config-Debug.xcconfig`:
   ```ini
   ADALO_API_KEY = 0pd83djfxdyh1ujb8hcz5ln6d  // Your current dev key
   ADALO_APP_ID = a03b07ee-0cee-4d06-82bb-75e4f6193332  // Your current app ID
   ```

2. **For Production** - Edit `Config-Release.xcconfig`:
   ```ini
   ADALO_API_KEY = your_production_api_key_here
   ADALO_APP_ID = your_production_app_id_here
   ```

### **Step 2: Configure Xcode Project**

1. **Open Xcode**
2. **Select your project** (top-level "shift" in navigator)
3. **Go to "shift" target** → "Build Settings"
4. **Search for "Configuration Files"**
5. **Set the configurations**:
   - **Debug**: `Config-Debug.xcconfig`
   - **Release**: `Config-Release.xcconfig`

### **Step 3: Add Files to Xcode** (if not automatically added)

1. **Right-click** on your project in Xcode navigator
2. **Add Files to "shift"**
3. **Select**:
   - `Config-Debug.xcconfig`
   - `Config-Release.xcconfig`
   - `shift/Info.plist`

## 🔐 **Security Best Practices**

### **✅ DO:**
- **Keep production keys separate** from development keys
- **Use different Adalo apps** for dev/staging/production
- **Add `.xcconfig` files to `.gitignore** if they contain sensitive data
- **Use environment-specific app bundle IDs**
- **Regularly rotate API keys**

### **❌ DON'T:**
- **Never hardcode API keys** in Swift files
- **Don't commit production credentials** to version control
- **Don't use the same API keys** for all environments

### **Recommended .gitignore additions:**
```gitignore
# Environment Configuration (uncomment if needed)
# Config-Release.xcconfig
# Config-Debug.xcconfig

# Keep these if you want to share dev settings with team:
# Config-Debug.xcconfig

# Always ignore production settings:
Config-Release.xcconfig
Config-Production.xcconfig
```

## 🎛 **Feature Flags**

Your setup now supports feature flags:

```swift
// In your Swift code:
if AdaloConfiguration.isDebugMenuEnabled {
    // Show debug menu only in development
}

if AdaloConfiguration.isLoggingEnabled {
    print("API Request: \(url)")
}
```

## 🏗 **Adding More Environments**

### **Staging Environment Example:**

1. **Create `Config-Staging.xcconfig`**:
   ```ini
   ADALO_API_KEY = your_staging_api_key
   ADALO_APP_ID = your_staging_app_id
   ENABLE_DEBUG_MENU = YES
   ENABLE_LOGGING = YES
   ```

2. **Create new Xcode scheme**:
   - Product → Scheme → Manage Schemes
   - Duplicate existing scheme
   - Name it "shift-Staging"
   - Set Build Configuration to "Staging"

3. **Add build configuration**:
   - Project settings → Configurations
   - Add "Staging" configuration
   - Set xcconfig file to `Config-Staging.xcconfig`

## 🧪 **Testing Your Configuration**

Use the **DB Test tab** in your app to verify:

1. **Run the app** in Debug mode
2. **Go to "DB Test" tab**
3. **Tap "Test Configuration"**
4. **Verify**:
   - ✅ API Key starts with expected characters
   - ✅ App ID matches your expectation
   - ✅ Environment shows "Development"

## 📱 **App Store Submission**

When building for App Store:

1. **Always use Release configuration**
2. **Archive** (not just Run)
3. **Verify production API keys** are being used
4. **Test on TestFlight** before public release

## 🔧 **Troubleshooting**

### **"AdaloAPIKey not found in Info.plist"**
- Check that `Info.plist` is added to your Xcode project
- Verify the xcconfig file is assigned to your build configuration

### **API calls failing**
- Verify API keys in `AdaloConnectionTest`
- Check that the correct configuration is being used
- Ensure Adalo account has proper permissions

### **Wrong environment values**
- Clean build folder (Product → Clean Build Folder)
- Check xcconfig file assignment in project settings
- Verify Info.plist has correct `$(VARIABLE)` references

## 🎯 **Quick Commands**

```bash
# Clean and rebuild to pick up configuration changes
Product → Clean Build Folder
Product → Build

# Switch between environments
- Use different Xcode schemes
- Or change Build Configuration in scheme settings
```

This setup provides **production-grade environment management** for your iOS app while maintaining security and following iOS development best practices! 