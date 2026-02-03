.PHONY: help all generate build build-all test test-all lint format clean install-hooks archive-ios archive-macos archive-watchos archive-all verify-universal

# Default target
all: generate

# Show help
help:
	@echo "🚀 HubWorks Build System"
	@echo ""
	@echo "📋 Available targets:"
	@echo ""
	@echo "  Project Setup:"
	@echo "    make setup              - Full setup (generate + resolve + hooks)"
	@echo "    make generate           - Generate Xcode project with XcodeGen"
	@echo "    make resolve            - Resolve Swift package dependencies"
	@echo "    make install-hooks      - Install git hooks"
	@echo ""
	@echo "  Building:"
	@echo "    make build              - Build all platforms (iOS, macOS, watchOS)"
	@echo "    make build-ios          - Build iOS only"
	@echo "    make build-macos        - Build macOS only"
	@echo "    make build-watchos      - Build watchOS only"
	@echo "    make verify-universal   - Verify macOS universal binary"
	@echo ""
	@echo "  Testing:"
	@echo "    make test               - Run all tests (iOS + macOS)"
	@echo "    make test-ios           - Run iOS tests only"
	@echo "    make test-macos         - Run macOS tests only"
	@echo ""
	@echo "  Code Quality:"
	@echo "    make lint               - Run SwiftLint"
	@echo "    make format             - Run SwiftFormat"
	@echo ""
	@echo "  Archiving:"
	@echo "    make archive-all        - Archive all platforms"
	@echo "    make archive-ios        - Archive iOS app"
	@echo "    make archive-macos      - Archive macOS app"
	@echo "    make archive-watchos    - Archive watchOS app"
	@echo ""
	@echo "  Utilities:"
	@echo "    make clean              - Clean build artifacts"
	@echo "    make open               - Open project in Xcode"
	@echo ""

# Generate Xcode project using XcodeGen
generate:
	xcodegen generate

# Build individual platforms
build-ios:
	@echo "🔨 Building iOS..."
	@xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-iOS -destination 'generic/platform=iOS' -configuration Debug

build-macos:
	@echo "🔨 Building macOS..."
	@xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-macOS -configuration Debug

build-watchos:
	@echo "🔨 Building watchOS..."
	@xcodebuild build -project HubWorks.xcodeproj -scheme HubWorks-watchOS -destination 'generic/platform=watchOS' -configuration Debug

# Build all platforms
build: build-ios build-macos build-watchos

build-all: build
	@echo "✅ All platforms built successfully!"

# Archive individual platforms with auto-incremented build number
archive-ios:
	@echo "📦 Archiving iOS app..."
	@BUILD_NUMBER=$$(git rev-list --count origin/main 2>/dev/null || git rev-list --count HEAD); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$$BUILD_NUMBER\"/g" project.yml
	@make generate
	@mkdir -p build
	@xcodebuild archive \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-iOS \
		-configuration Release \
		-archivePath ./build/HubWorks-iOS.xcarchive \
		-skipMacroValidation
	@echo "✅ iOS archived to build/HubWorks-iOS.xcarchive"

archive-macos:
	@echo "📦 Archiving macOS app..."
	@BUILD_NUMBER=$$(git rev-list --count origin/main 2>/dev/null || git rev-list --count HEAD); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$$BUILD_NUMBER\"/g" project.yml
	@make generate
	@mkdir -p build
	@xcodebuild archive \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-macOS \
		-configuration Release \
		-archivePath ./build/HubWorks-macOS.xcarchive \
		-skipMacroValidation
	@echo "✅ macOS archived to build/HubWorks-macOS.xcarchive"

archive-watchos:
	@echo "📦 Archiving watchOS app..."
	@BUILD_NUMBER=$$(git rev-list --count origin/main 2>/dev/null || git rev-list --count HEAD); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"[0-9]*\"/CURRENT_PROJECT_VERSION: \"$$BUILD_NUMBER\"/g" project.yml
	@make generate
	@mkdir -p build
	@xcodebuild archive \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-watchOS \
		-configuration Release \
		-archivePath ./build/HubWorks-watchOS.xcarchive \
		-skipMacroValidation
	@echo "✅ watchOS archived to build/HubWorks-watchOS.xcarchive"

# Archive all platforms
archive-all: archive-ios archive-macos archive-watchos
	@echo "🎉 All platforms archived!"

# Verify macOS builds as universal binary
verify-universal:
	@echo "🔍 Verifying macOS universal binary..."
	@xcodebuild build \
		-project HubWorks.xcodeproj \
		-scheme HubWorks-macOS \
		-configuration Release \
		-destination 'platform=macOS,arch=arm64' \
		-destination 'platform=macOS,arch=x86_64'
	@BINARY=$$(find ~/Library/Developer/Xcode/DerivedData -name "HubWorks" -type f -perm +111 | head -1); \
	if [ -z "$$BINARY" ]; then \
		echo "❌ Binary not found"; \
		exit 1; \
	fi; \
	echo "📦 Checking binary: $$BINARY"; \
	lipo -info "$$BINARY"; \
	if lipo -info "$$BINARY" | grep -q "arm64.*x86_64\|x86_64.*arm64"; then \
		echo "✅ Universal binary verified (arm64 + x86_64)"; \
	else \
		echo "❌ Not a universal binary"; \
		exit 1; \
	fi

# Run tests on individual platforms
test-ios:
	@echo "🧪 Testing iOS..."
	@xcodebuild test -project HubWorks.xcodeproj -scheme HubWorks-iOS -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug

test-macos:
	@echo "🧪 Testing macOS..."
	@xcodebuild test -project HubWorks.xcodeproj -scheme HubWorks-macOS -configuration Debug

# Run all tests (iOS + macOS, watchOS doesn't have tests)
test: test-ios test-macos

test-all: test
	@echo "✅ All tests passed!"

# Lint code with SwiftLint
lint:
	swiftlint lint --config .swiftlint.yml

# Format code with SwiftFormat
format:
	swiftformat . --config .swiftformat

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@xcodebuild clean -project HubWorks.xcodeproj -scheme HubWorks-iOS 2>/dev/null || true
	@xcodebuild clean -project HubWorks.xcodeproj -scheme HubWorks-macOS 2>/dev/null || true
	@xcodebuild clean -project HubWorks.xcodeproj -scheme HubWorks-watchOS 2>/dev/null || true
	@rm -rf build/
	@rm -rf DerivedData/
	@rm -rf ~/Library/Developer/Xcode/DerivedData/HubWorks-*
	@echo "✅ Clean complete!"

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
