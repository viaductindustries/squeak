# Squeek

- Swift package: `SqueekCore` holds the logic and is tested; `Squeek` is the SwiftUI menu bar app.
- Run `make test` for tests and `make install` to try it in the real app.
- Check settings window changes with `swift run Squeek --snapshot /tmp/squeek-shots` (light and dark).
- Keep the event tap callback fast: decide in `ButtonRouter`, run actions asynchronously.
