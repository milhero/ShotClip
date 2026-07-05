APP_NAME := ShotClip
BUNDLE   := dist/$(APP_NAME).app
BINARY   := .build/release/$(APP_NAME)
ICON_PNG := Resources/AppIcon.png
ICONSET  := .build/AppIcon.iconset
ICNS     := .build/AppIcon.icns

.PHONY: build app install icon clean

build:
	swift build -c release

icon: $(ICNS)

$(ICNS): $(ICON_PNG)
	rm -rf "$(ICONSET)"
	mkdir -p "$(ICONSET)"
	sips -z 16 16     "$(ICON_PNG)" --out "$(ICONSET)/icon_16x16.png" >/dev/null
	sips -z 32 32     "$(ICON_PNG)" --out "$(ICONSET)/icon_16x16@2x.png" >/dev/null
	sips -z 32 32     "$(ICON_PNG)" --out "$(ICONSET)/icon_32x32.png" >/dev/null
	sips -z 64 64     "$(ICON_PNG)" --out "$(ICONSET)/icon_32x32@2x.png" >/dev/null
	sips -z 128 128   "$(ICON_PNG)" --out "$(ICONSET)/icon_128x128.png" >/dev/null
	sips -z 256 256   "$(ICON_PNG)" --out "$(ICONSET)/icon_128x128@2x.png" >/dev/null
	sips -z 256 256   "$(ICON_PNG)" --out "$(ICONSET)/icon_256x256.png" >/dev/null
	sips -z 512 512   "$(ICON_PNG)" --out "$(ICONSET)/icon_256x256@2x.png" >/dev/null
	sips -z 512 512   "$(ICON_PNG)" --out "$(ICONSET)/icon_512x512.png" >/dev/null
	cp "$(ICON_PNG)" "$(ICONSET)/icon_512x512@2x.png"
	iconutil -c icns "$(ICONSET)" -o "$(ICNS)"

app: build icon
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS" "$(BUNDLE)/Contents/Resources"
	cp "$(BINARY)" "$(BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp "$(ICNS)" "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	codesign --force --sign - "$(BUNDLE)"
	@echo "✓ Built $(BUNDLE)"

install: app
	rm -rf "/Applications/$(APP_NAME).app"
	cp -R "$(BUNDLE)" /Applications/
	open "/Applications/$(APP_NAME).app"
	@echo "✓ Installed — look for the camera icon in the menu bar"

clean:
	rm -rf .build dist
