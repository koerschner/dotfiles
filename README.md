# Dotfiles

Nathan's personal machine config: shell, editor, terminal, git, window management, a `Brewfile`,
macOS defaults, an idempotent `bootstrap`, and per-machine snapshots under `machines/` so drift shows
up in git. Configs are stowed with `stow --dotfiles`.

The agent system (tmux via ag-mux + Pi, ag-dash, the ag-inbox, ag-tickler, bridge, infra, agent instructions and
skills) lives in its own private repo, **ag** (`koerschner/ag`). `bootstrap` clones it to `~/ag`
and runs `~/ag/install`; see its README for everything agent-related, including the secrets list.

Machines stay in sync over git only; nothing is shared over the network.

## New machine

Goal: get a ChatGPT agent running first, then let it do the rest.

### 1. Get ChatGPT going (by hand, ~5 min)

1. Sign in to the Mac with the Apple ID; connect Wi-Fi.
2. Install [ChatGPT desktop](https://developers.openai.com/codex/app/) from a
   browser, sign in with the normal ChatGPT account, and pick **Codex**.
   Plain ChatGPT auth works until step 3; TrueFoundry isn't needed yet.
3. Grant it computer-use access (Accessibility, Screen Recording) when it asks.

### 2. Hand off to ChatGPT

Paste this into a Codex chat:

```text
Set up this Mac to parity with my main machine using my dotfiles. Read
https://github.com/koerschner/dotfiles/blob/main/README.md first, then run
the bootstrap:

  zsh -c "$(curl -fsSL https://raw.githubusercontent.com/koerschner/dotfiles/main/bootstrap)"

It is idempotent: re-run it after anything that needed me (Command Line Tools
dialog, sudo password, gh auth login, app sign-ins). Work through the
"Needs attention" list it prints and the "After bootstrap" section of the
README. Bring me in only for passwords, sign-ins, MFA, and macOS permission
prompts. Never print, commit, or paste secrets into chat. Finish by running
~/dotfiles/snapshot and reporting what is still different from the other
machine's snapshot in ~/dotfiles/machines/.
```

### 3. What bootstrap does

`~/dotfiles/bootstrap [--macos]`, safe to re-run:

1. Xcode Command Line Tools, Homebrew, clones this repo to `~/dotfiles`.
2. `brew bundle` (`Brewfile`: CLIs, apps, global npm/uv tools). Apps already
   installed by hand make their cask fail; that's harmless.
3. oh-my-zsh.
4. Stows every package here into `~`. Any real file in the way moves to
   `~/.dotfiles-backup/<timestamp>/`.
5. Clones the private ag repo to `~/ag` (after `gh auth login`) and runs
   `~/ag/install`: agent CLIs (bun, claude, codex, amp, omp), agent
   instructions, ag's stow packages, LaunchAgents, helper apps, shortcut check.
6. `mise install`, nvim plugins at the versions in `lazy-lock.json`.
7. `--macos`: applies the `macos` defaults script (Dock, keyboard, Finder,
   power settings by role: the host never sleeps, clients sleep normally;
   uses sudo). Reboot afterward.
8. Clones every repo in `machines/*/repos.txt` into `~` (after `gh auth login`).
9. Prints a secrets checklist and anything that needs attention.

### 4. Secrets (move by hand; never commit)

The full list (files, vault items, 1Password service-account tokens) is in the
ag README, section "Secrets". Personal-config ones: `~/.zshenv.local`,
`~/.gitconfig.local`, `~/.zprofile.local`, `~/.profile.local`.

### 5. After bootstrap (by hand)

- `gh auth login`, then re-run bootstrap to clone repos.
- Sign in: Chrome (turn on sync, set as default browser), 1Password, Slack,
  Discord, Linear, Spotify, Tailscale, Jump Desktop.
- On ag, Chrome's Default profile must stay signed in to Google as
  `nathankoerschner@gmail.com` (Gmail loads, not just Chrome sync): agents read
  email verification codes there with `ag-chatgpt-cua` instead of driving the
  client. Check: `.google.com` `SID` cookie exists in
  `~/Library/Application Support/Google/Chrome/Default/Cookies`. If Google shows
  "Signed out", ask Nathan to sign in again (password + 2FA).
- Alfred: activate Powerpack, set the preferences folder to `~/.alfred`, turn
  off the Spotlight shortcut.
- Hammerspoon: grant Accessibility and enable launch at login. Change Caps Lock
  to Control in System Settings > Keyboard.
- Open Ghostty and run `ag` to attach to the sessions on the session host.
- Apps with no cask: see `manual-apps.txt`.
- Mission Control shortcuts aren't scriptable; set them by hand.
- Host (ag): in System Settings > Apple Account > iCloud, turn on Reminders
  sync so agents can read Nathan's reminders (the local store under
  `~/Library/Group Containers/group.com.apple.reminders/`).
- Optional: `:MasonInstall sqlfmt` in nvim where SQL formatting is wanted.

## Keeping machines at parity

Run `~/dotfiles/snapshot --commit` after installing or removing things. It
writes `machines/<host>/` (Brewfile dump, apps, repos, LaunchAgents, mise and
bun globals) and commits it. `machines/<host>/unmanaged.txt` is the drift
report:

- *installed here but not in Brewfile*: add it to `Brewfile` (or
  `manual-apps.txt`) so other machines get it, or uninstall it.
- *declared but not brew-installed here*: run bootstrap, or ignore apps that
  were installed by hand before this machine used the Brewfile.

On every other machine (see `~/ag/machines/README.md`), `git pull && ./bootstrap` picks up the change. Config
files are symlinks into this repo, so config edits are already tracked:
commit them, pull elsewhere.

Configs use `$HOME`, so they symlink on any user. Exception: `~/.codex/config.toml`
is a per-host copy (Codex rewrites it with absolute paths). Per-host Ghostty
settings go in untracked `~/.config/ghostty/local.conf`.

Small personal helper scripts live in `bin/dot-local/bin` and stow into `~/.local/bin` (agent helpers are in ag).

Every top-level directory except `machines/` (snapshots) is a stow package; `bootstrap` lists them in `STOW_PACKAGES`. The machine inventory is `~/ag/machines/README.md`.

## TMUX Cheat Sheet

`Prefix` means press `Ctrl+B`, release it, then press the shortcut key.

| Shortcut | Action |
|---|---|
| `Prefix f` | Open the project sessionizer |
| `Prefix L` | Switch to the last-used session |
| `Prefix (` / `Prefix )` | Previous / next session |
| `Prefix s` | Pick a session |
| `Prefix c` | Create a window |
| `Prefix n` / `Prefix p` | Next / previous window |
| `Prefix 1`–`9` | Jump to a numbered window |
| `Prefix %` / `Prefix "` | Split right / split down |
| `Prefix h/j/k/l` | Move between panes |
| `Prefix z` | Zoom or unzoom the current pane |
| `Prefix x` | Close the current pane |
| `Prefix i` | Copy the current pane ID |
