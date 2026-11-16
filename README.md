# Squeek

A menu bar app for macOS 15 and later that decides what your mouse buttons do.
By default the side buttons do nothing, so browsers stop going back and forward.

## Actions

| Action | What it does |
|---|---|
| Do nothing | The press is swallowed. This is the default for Back and Forward. |
| Normal | The press goes through untouched. |
| Pass to other apps | Ignored when the pointer is over a browser window; every other app sees the button as normal (for push-to-talk, game bindings and so on). |
| Keyboard shortcut | Sends a recorded key combination, held for as long as the button is held. |
| Middle click | Acts like pressing the scroll wheel. |
| Mission Control, App windows, Show desktop | The usual macOS gestures. |
| Previous desktop, Next desktop | Sends ⌃← and ⌃→, so those shortcuts need to be turned on in System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Mission Control (they are by default). |
| Open app | Opens or switches to an app. |

Back and Forward are always listed. **Add Button…** waits for you to press any
other button (middle, or extra buttons on bigger mice). Left and right clicks
are never touched.

## Building

```sh
make install   # build, sign, copy to /Applications and open
make test      # run the tests
```

Squeek needs **Accessibility** access (System Settings ▸ Privacy & Security ▸
Accessibility). The build is signed with your Apple Development certificate so
the permission survives rebuilds. Use `make install SIGN_ID="…"` to sign with
something else.

`swift run Squeek --snapshot <directory>` renders the settings window in a few
states, in light and dark, without touching your settings or mouse.

## How it works

An event tap sees every middle and extra mouse button event before apps do.
`ButtonRouter` (in `SqueekCore`, with tests) decides on each press whether to
pass it, swallow it, rewrite it as another button, or run an action, and keeps
that decision until the button is released.

"Pass to other apps" swallows the press over browsers rather than sending it
as a different button number: Chrome and Safari ignore unknown buttons, but
Firefox treats them all as a middle click.
