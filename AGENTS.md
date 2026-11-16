# Squeak

## Ground rules

- **Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/).** Release Please builds the version and changelog from them.
  - `feat:` user-visible feature, `fix:` bug fix, `perf:` performance.
  - `refactor:`, `docs:`, `test:`, `ci:`, `build:`, `chore:` for everything else.
  - Breaking changes: `feat!:` / `fix!:` or a `BREAKING CHANGE:` footer.
  - Write the subject in the imperative mood, lower case, with no trailing full stop, and explain why in the body.
- **Releases are signed and notarized on GitHub Actions**, in the same way as Cert Lab. Release Please opens release PRs; merging one creates the tag and GitHub Release, and the same workflow builds, signs, notarizes and attaches the download, then opens a Homebrew tap PR. Release Please maintains `version.txt`, so don't bump it by hand. See `docs/releases.md`.
- **Don't push, tag or change GitHub settings unless asked.** The remote is `viaductindustries/squeak`.
- Run `swift test` before committing.

## Project layout

- Swift Package Manager only; there's no Xcode project. The app needs macOS 15 or later.
  - `Sources/SqueakCore`: the logic (`ButtonRouter`, `SyntheticKeyboard`, settings), with no UI. Anything testable goes here.
  - `Sources/Squeak`: the SwiftUI menu bar app.
  - `Tests/SqueakCoreTests`: Swift Testing (`@Test`), not XCTest.
- `scripts/build-app.sh [--install] [--universal]` bundles `build/Squeak.app`. It takes the version from `version.txt` and the build number from `$BUILD_NUMBER` or the git commit count, and signs with your Apple Development identity so the Accessibility permission survives rebuilds.
- CI is `.github/workflows/ci.yml`: tests and a universal app build on pushes to `main` and PRs. `.github/workflows/release.yml` runs Release Please and, for new releases, signs and notarizes with `scripts/notarize-app.sh`. Keep the signing job in that workflow rather than a reusable one: GitHub leaves environment secrets empty in called workflows unless the caller uses `secrets: inherit`.
  - Pin third-party actions to a full commit SHA with a `# vX.Y.Z` comment; Dependabot proposes updates after a 7-day cooldown. Check out with `persist-credentials: false` and give each job only the permissions it needs, with a comment saying why. `zizmor .github` should report nothing above `help`.

## Working on the app

- Try changes in the real app with `scripts/build-app.sh --install`.
- Check settings window changes with `swift run Squeak --snapshot /tmp/squeak-shots` (light and dark).
- Name buttons by number (Middle, Button 4, Button 5…), not Back and Forward: that's a browser habit, not something macOS reports.
- Keep the event tap callback fast: decide in `ButtonRouter`, run actions asynchronously.
