.PHONY: all generate build test lint format clean install-hooks archive-ios archive-macos

# Default target
all: generate

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Build iOS target
build-ios:
	xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-iOS -destination 'generic/platform=iOS' -configuration Debug

# Build macOS target
build-macos:
	xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-macOS -configuration Debug

# Build watchOS target
build-watchos:
	xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-watchOS -destination 'generic/platform=watchOS' -configuration Debug

# Build all targets
build: build-ios build-macos

# Archive iOS app with auto-incremented build number
archive-ios:
	@echo "Incrementing build number..."
	@BUILD_NUMBER=$$(git rev-list --count HEAD); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$$BUILD_NUMBER\"/g" project.yml
	@make generate
	@echo "Archiving iOS app..."
	@mkdir -p build
	xcodebuild archive \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-iOS \
		-configuration Release \
		-archivePath ./build/HubWorks-iOS.xcarchive

# Archive macOS app with auto-incremented build number
archive-macos:
	@echo "Incrementing build number..."
	@BUILD_NUMBER=$$(git rev-list --count HEAD); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$$BUILD_NUMBER\"/g" project.yml
	@make generate
	@echo "Archiving macOS app..."
	@mkdir -p build
	xcodebuild archive \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-macOS \
		-configuration Release \
		-archivePath ./build/HubWorks-macOS.xcarchive

# Run tests
test:
	xcodebuild test -project HubWorks.xcodeproj -scheme HubWorks-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug

# Lint code with SwiftLint
lint:
	swiftlint lint --config .swiftlint.yml

# Format code with SwiftFormat
format:
	swiftformat . --config .swiftformat

# Clean build artifacts
clean:
	xcodebuild clean -project HubWorks.xcodeproj -scheme HubWorks-iOS
	xcodebuild clean -project HubWorks.xcodeproj -scheme HubWorks-macOS
	rm -rf build/
	rm -rf DerivedData/

# Resolve Swift package dependencies
resolve:
	xcodebuild -resolvePackageDependencies -project HubWorks.xcodeproj

# Open project in Xcode
open:
	open HubWorks.xcodeproj

# Install git hooks
install-hooks:
	git config core.hooksPath .githooks
	@echo "Git hooks installed from .githooks/"

# Full setup (generate + resolve dependencies + hooks)
setup: generate resolve install-hooks
