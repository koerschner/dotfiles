---
description: ⌘V of an image in an Ag terminal pastes its path on the session host
on: hammerspoon
code: rule.lua
enabled: true
---
Sessions run on the session host, so an image on my Mac's clipboard can't reach them directly. When I press
⌘V in a Ghostty window showing Ag with an image (or copied image files) on the clipboard, the image is
uploaded to the session host's ~/inbox/clipboard/ and its path is typed instead, which Pi reads as an
attachment. Plain text pastes are untouched. To make it instant, every new CleanShot capture is uploaded the
moment it's saved, so pasting it just types the path. Not on the session host itself.
