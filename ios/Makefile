.PHONY: generate build test clean

generate:
	xcodegen generate

build: generate
	xcodebuild build \
		-project Recall.xcodeproj \
		-scheme Recall \
		-destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
		-configuration Debug \
		CODE_SIGNING_ALLOWED=NO

test: generate
	xcodebuild test \
		-project Recall.xcodeproj \
		-scheme RecallTests \
		-destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
		CODE_SIGNING_ALLOWED=NO

clean:
	rm -rf DerivedData build
	xcodebuild clean -project Recall.xcodeproj -scheme Recall 2>/dev/null || true
