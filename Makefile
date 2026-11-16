APP := build/Squeek.app
# Signing with a real certificate keeps the Accessibility permission across rebuilds.
SIGN_ID ?= Apple Development

.PHONY: app test install run clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp Support/Info.plist $(APP)/Contents/Info.plist
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
