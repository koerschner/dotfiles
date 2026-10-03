---
description: Both Command keys open the quick entry box (with Shift, a screenshot is attached)
on: keys
app: ag-dash-app
code: keys.json
enabled: true
---
On the Mac I sit at, pressing both Command keys together, anywhere, opens the ag-dash app's quick entry box,
which sends what I type to the ag-inbox as a new session. Holding Shift as well first grabs a screenshot of
the screen under the mouse (so the box isn't in it) and always attaches it; click it to annotate. Images I
paste into the box (⌘V, e.g. a CleanShot copy) are attached too.

In the box: Enter sends, ⌘Enter sends and pins the new session, ⇧Enter is a new line, Esc closes it.

Code: the ag-dash app (macos-apps/ag-dash/app: hotkeys.js watches the chord, main.js takes the screenshot,
entry.js/entry.html are the box) runs these bindings. Its first use asks macOS for Accessibility (the chord)
and Screen Recording (the screenshot) for ag-dash.
