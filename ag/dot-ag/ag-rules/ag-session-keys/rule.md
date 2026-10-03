---
description: Ag's session shortcuts (tabs, splits, focus history) on every device
on: keys
app: ag-session
code: keys.json
enabled: true
---
One set of shortcuts for Ag's sessions (tmux) on every device. On a Mac, in a Ghostty window showing Ag
(title "ag: …"): ⌘T new tab running Pi, ⌘W close the pane, ⇧⌘T reopen the closed pane, ⌘D split side by side,
⇧⌘D split stacked, ⌘[ / ⌘] back / forward in focus history, ⌘1–9 switch to tab 1–9. Everywhere else (the
phone in Moshi, any terminal): Ctrl+B then the same key (t, x, u, v, -, [, ], 1–9). Outside Ag windows the
⌘ keys keep Ghostty's own meaning.

Code: the keymap (.json) is read by Hammerspoon (ag.lua turns each ⌘ key into the Ctrl+B chord) and checked
against tmux's bindings (tmux/dot-config/ag/ag.tmux.conf) by ag-shortcuts-check, which also regenerates the
table in tmux/SHORTCUTS.md.
