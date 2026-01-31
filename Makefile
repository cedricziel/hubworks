.PHONY: all generate build test lint format clean

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

# Run tests
test:
	xcodebuild test -project HubWorks.xcodeproj -scheme HubWorks-iOS -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug

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

# Full setup (generate + resolve dependencies)
setup: generate resolve
