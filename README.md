# dropbox-open

Menu-bar macOS app for turning a Dropbox file into a one-click Finder reveal, shareable
as a link in Slack, Notion, wherever.

Its really annoying that Dropbox doesn't make this easier. I saw the open in Finder capabilites on their website and thought they'd have some way to do this, but there is no easy path. So here it is.

## Components

- **Dropbox Deeplink.app**, menu-bar only, no Dock icon. "Add Dropbox Workspace..." picks
  one local synced copy of a shared Dropbox folder. You can add more than one workspace
  for multi-account or multi-team setups. Registers the `dbxopen://` URL scheme:
  clicking a `dbxopen://workspace/path/to/file` link resolves it against the matching
  local workspace and reveals the file in Finder. Shows an alert (not a silent no-op)
  if the workspace or file can't be found locally.
- **"Copy Dropbox Deeplink" Finder Quick Action**, right-click any file, copies its
  `dbxopen://` link to the clipboard.

## Build

```
./Scripts/build-app.sh
```

Produces a signed `dist/Dropbox Deeplink.app` and `dist/Dropbox Deeplink.zip`. Set `NOTARIZE=1`
to also notarize and staple.

## Install (once released)

```
brew tap zm2231/tap
brew install --cask dropbox-open
```

Installs the app and the Finder Quick Action.

## Use

1. Click the menu-bar icon, "Add Dropbox Workspace...", pick your local synced copy
   of a shared Dropbox folder. The app assigns a workspace id from the folder name
   (for example `Quoxient` becomes `quoxient`).
2. Click any `dbxopen://...` link (Slack, wiki, wherever). Finder reveals the file.
3. Or: right-click any file in a configured workspace in Finder, "Copy Dropbox
   Deeplink". If more than one workspace matches, the deepest/longest workspace root
   wins.

New links include the workspace id:

```
dbxopen://quoxient/Reports/2026-05-09-research-pass2-generational-psychology.md
```

Older single-root links like `dbxopen://Reports%2Ffile.md` still resolve against the
default workspace.

## Known limits (v1)

- macOS only.
- The right-click action currently appears on every file in Finder, not just files
  inside your configured Dropbox workspaces. Clicking it on a file outside those folders shows a
  clear error instead of copying a broken link. Restricting *where the menu item shows
  up* to just the team folder isn't possible with a Finder Quick Action (Apple's
  Services menu matches by file type, not by location); it would require a Finder Sync
  Extension instead, a bigger build. Open item if this becomes a real annoyance.
- Multiple Dropbox accounts on one machine are supported by adding one workspace root
  per synced shared folder. Links require teammates to use the same workspace id.
- Assumes everyone's synced copy of each workspace has the same relative structure.
