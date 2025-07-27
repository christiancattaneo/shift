#!/bin/bash

# Repository cleanup script - Remove large files from git history
# This will rewrite git history - make sure all team members are aware!

echo "🔍 Shift Repository Cleanup Script"
echo "================================="
echo ""
echo "⚠️  WARNING: This will rewrite git history!"
echo "Make sure all team members have pushed their changes."
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Create a backup branch
echo ""
echo "📋 Creating backup branch..."
git branch backup-before-cleanup

# Remove adalo_data directory from all commits
echo ""
echo "🗑️  Removing adalo_data directory from git history..."
git filter-branch --force --index-filter \
  'git rm -r --cached --ignore-unmatch adalo_data/' \
  --prune-empty --tag-name-filter cat -- --all

# Also remove firebase_migration_data if it exists in history
echo ""
echo "🗑️  Removing firebase_migration_data directory from git history..."
git filter-branch --force --index-filter \
  'git rm -r --cached --ignore-unmatch firebase_migration_data/' \
  --prune-empty --tag-name-filter cat -- --all

# Clean up
echo ""
echo "🧹 Cleaning up git objects..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Show new repository size
echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Old repository size: 1.7G"
echo -n "New repository size: "
du -sh .git

echo ""
echo "📌 Next steps:"
echo "1. Test that everything works correctly"
echo "2. Force push to remote: git push origin --force --all"
echo "3. Have all team members delete their local repos and clone fresh"
echo "4. Delete the backup branch when confirmed: git branch -D backup-before-cleanup"
echo ""
echo "💡 Consider uploading adalo_data to cloud storage for reference" 