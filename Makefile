APP := build/Squeak.app
# Signing with a real certificate keeps the Accessibility permission across rebuilds.
SIGN_ID ?= Apple Development

.PHONY: app test install run clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Support/Info.plist $(APP)/Contents/Info.plist
	xcrun actool $(CURDIR)/Support/AppIcon.icon --compile $(CURDIR)/$(APP)/Contents/Resources \
		--platform macosx --minimum-deployment-target 15.0 --app-icon AppIcon \
		--output-partial-info-plist $(CURDIR)/build/icon-info.plist > /dev/null
	cp "$$(swift build -c release --show-bin-path)/Squeak" $(APP)/Contents/MacOS/Squeak
	codesign --force --options runtime --sign "$(SIGN_ID)" $(APP)

test:
	swift test

install: app
	-pkill -x Squeak
	rm -rf /Applications/Squeak.app
	cp -R $(APP) /Applications/Squeak.app
	open /Applications/Squeak.app

run: app
	-pkill -x Squeak
	open $(APP)

clean:
	rm -rf .build build
