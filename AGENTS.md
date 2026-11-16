# Squeak

- Swift package: `SqueakCore` holds the logic and is tested; `Squeak` is the SwiftUI menu bar app.
- Run `make test` for tests and `make install` to try it in the real app.
- Check settings window changes with `swift run Squeak --snapshot /tmp/squeak-shots` (light and dark).
- Name buttons by number (Middle, Button 4, Button 5…), not Back and Forward: that's a browser habit, not something macOS reports.
- Keep the event tap callback fast: decide in `ButtonRouter`, run actions asynchronously.
