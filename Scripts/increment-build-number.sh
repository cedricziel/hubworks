#!/bin/bash
set -e

# This script increments the build number based on git commit count
# It only runs for Release builds to avoid constant regeneration during development

# Only run for Release configuration
if [ "${CONFIGURATION}" != "Release" ]; then
    echo "ℹ️ Skipping build number increment (not a Release build)"
    exit 0
fi

# Get the project root
PROJECT_ROOT="${SRCROOT}"

# Calculate build number from git commit count
if [ -d "${PROJECT_ROOT}/.git" ]; then
    BUILD_NUMBER=$(git -C "${PROJECT_ROOT}" rev-list --count HEAD)
    echo "📊 Calculated build number from git: ${BUILD_NUMBER}"
else
    echo "⚠️ Not a git repository, keeping existing build number"
    exit 0
fi

# Update the Info.plist directly in the built product
# This is more reliable than regenerating the project during build
INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

if [ -f "${INFO_PLIST}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFO_PLIST}"
    echo "✅ Updated ${INFOPLIST_PATH} with build number: ${BUILD_NUMBER}"
else
    # Fallback: update the source Info.plist if the built one doesn't exist yet
    SOURCE_INFO_PLIST="${PROJECT_ROOT}/${INFOPLIST_FILE}"
    if [ -f "${SOURCE_INFO_PLIST}" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "${SOURCE_INFO_PLIST}"
        echo "✅ Updated source Info.plist with build number: ${BUILD_NUMBER}"
    else
        echo "⚠️ Info.plist not found, build number not updated"
        echo "   Tried: ${INFO_PLIST}"
        echo "   Tried: ${SOURCE_INFO_PLIST}"
        # Don't fail the build if we can't update the plist
        exit 0
    fi
fi
