#!/bin/bash
set -e

# This script increments the build number based on git commit count
# It only runs for Release builds to avoid constant regeneration during development

# Only run for Release configuration
if [ "${CONFIGURATION}" != "Release" ]; then
    echo "Skipping build number increment (not a Release build)"
    exit 0
fi

# Get the project root (where project.yml lives)
PROJECT_ROOT="${SRCROOT}"

# Calculate build number from git commit count
if [ -d "${PROJECT_ROOT}/.git" ]; then
    BUILD_NUMBER=$(git -C "${PROJECT_ROOT}" rev-list --count HEAD)
    echo "Calculated build number from git: ${BUILD_NUMBER}"
else
    echo "Warning: Not a git repository, keeping existing build number"
    exit 0
fi

# Update project.yml with the new build number
PROJECT_YML="${PROJECT_ROOT}/project.yml"
if [ -f "${PROJECT_YML}" ]; then
    # Use perl for in-place editing (more portable than sed -i)
    perl -pi -e "s/CURRENT_PROJECT_VERSION: '[0-9]+'/CURRENT_PROJECT_VERSION: '${BUILD_NUMBER}'/g" "${PROJECT_YML}"
    echo "Updated project.yml with build number: ${BUILD_NUMBER}"

    # Regenerate Xcode project
    echo "Regenerating Xcode project..."
    cd "${PROJECT_ROOT}"
    xcodegen generate
    echo "Build number updated to ${BUILD_NUMBER}"
else
    echo "Error: project.yml not found at ${PROJECT_YML}"
    exit 1
fi
