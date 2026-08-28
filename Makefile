APP_NAME := BatchPrint
BUILD_DIR := .build/release
APP_DIR := dist/$(APP_NAME).app

.PHONY: build app clean

build:
	swift build -c release

app: build
	rm -rf "$(APP_DIR)"
	mkdir -p "$(APP_DIR)/Contents/MacOS"
	mkdir -p "$(APP_DIR)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_DIR)/Contents/MacOS/$(APP_NAME)"
	cp Support/Info.plist "$(APP_DIR)/Contents/Info.plist"
	printf 'APPL????' > "$(APP_DIR)/Contents/PkgInfo"
	@echo "已生成 $(APP_DIR)"

clean:
	swift package clean
	rm -rf dist
