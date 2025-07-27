#!/bin/bash

# Alternative approach - Archive large files without rewriting history
# This is safer but won't reduce repository size

echo "📦 Shift Large Files Archival Script"
echo "===================================="
echo ""
echo "This script will:"
echo "1. Create a compressed archive of adalo_data"
echo "2. Remove the directory from the working tree"
echo "3. Commit the removal"
echo ""
echo "This is safer than rewriting history but won't reduce .git size"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Create archive
echo ""
echo "📦 Creating compressed archive..."
tar -czf adalo_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz adalo_data/
echo "✅ Archive created: adalo_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz"

# Remove directory
echo ""
echo "🗑️  Removing adalo_data directory..."
rm -rf adalo_data/

# Check if firebase_migration_data exists and archive it too
if [ -d "firebase_migration_data" ]; then
    echo ""
    echo "📦 Archiving firebase_migration_data..."
    tar -czf firebase_migration_data_backup_$(date +%Y%m%d_%H%M%S).tar.gz firebase_migration_data/
    rm -rf firebase_migration_data/
fi

# Stage and commit
echo ""
echo "📝 Committing removal..."
git add -A
git commit -m "Remove large migration data directories - archived locally"

echo ""
echo "✅ Complete!"
echo ""
echo "📌 Next steps:"
echo "1. Upload the .tar.gz files to cloud storage (AWS S3, Google Drive, etc)"
echo "2. Add .tar.gz to .gitignore if not already there"
echo "3. Push changes: git push"
echo ""
echo "⚠️  Note: This doesn't reduce .git size. For that, use fix_large_files.sh" 