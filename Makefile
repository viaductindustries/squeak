APP := build/Squeek.app
# Signing with a real certificate keeps the Accessibility permission across rebuilds.
SIGN_ID ?= Apple Development

.PHONY: app test install run clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Support/Info.plist $(APP)/Contents/Info.plist
	xcrun actool Support/AppIcon.icon --compile $(APP)/Contents/Resources \
		--platform macosx --minimum-deployment-target 15.0 --app-icon AppIcon \
		--output-partial-info-plist build/icon-info.plist > /dev/null
	cp "$$(swift build -c release --show-bin-path)/Squeek" $(APP)/Contents/MacOS/Squeek
	codesign --force --options runtime --sign "$(SIGN_ID)" $(APP)

test:
	swift test

install: app
	-pkill -x Squeek
	rm -rf /Applications/Squeek.app
	cp -R $(APP) /Applications/Squeek.app
	open /Applications/Squeek.app

run: app
	-pkill -x Squeek
	open $(APP)

clean:
	rm -rf .build build
