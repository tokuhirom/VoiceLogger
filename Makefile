.PHONY: build debug release clean test run help

BUILD_DIR = build
DERIVED_DATA = $(BUILD_DIR)/DerivedData

# Default target
all: build

# Build (Debug configuration)
build:
	xcodebuild -project VoiceLogger.xcodeproj -scheme VoiceLogger -configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		CONFIGURATION_BUILD_DIR=$(PWD)/$(BUILD_DIR)/Debug \
		build

# Debug build (alias)
debug: build

# Release build
release:
	xcodebuild -project VoiceLogger.xcodeproj -scheme VoiceLogger -configuration Release \
		-derivedDataPath $(DERIVED_DATA) \
		CONFIGURATION_BUILD_DIR=$(PWD)/$(BUILD_DIR)/Release \
		build

# Clean build artifacts
clean:
	xcodebuild clean -project VoiceLogger.xcodeproj -scheme VoiceLogger
	rm -rf $(BUILD_DIR)/

# Run tests
test:
	xcodebuild test -project VoiceLogger.xcodeproj -scheme VoiceLogger -destination 'platform=macOS'

# Run the app (Debug)
run: build
	open $(BUILD_DIR)/Debug/VoiceLogger.app

# Run the app (Release)
run-release: release
	open $(BUILD_DIR)/Release/VoiceLogger.app

# Open project in Xcode
xcode:
	open VoiceLogger.xcodeproj

# Show help
help:
	@echo "Available targets:"
	@echo "  build       - Build debug configuration (default)"
	@echo "  debug       - Build debug configuration"
	@echo "  release     - Build release configuration"
	@echo "  clean       - Clean build artifacts"
	@echo "  test        - Run unit tests"
	@echo "  run         - Build and run debug app"
	@echo "  run-release - Build and run release app"
	@echo "  xcode       - Open project in Xcode"
	@echo "  help        - Show this help"
