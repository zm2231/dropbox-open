# dropbox-open

Menu-bar macOS app for turning a Dropbox file into a one-click Finder reveal, shareable
as a link in Slack, Notion, wherever.

Its really annoying that Dropbox doesn't make this easier. I saw the open in Finder capabilites on their website and thought they'd have some way to do this, but there is no easy path. So here it is.

## Components

- **Dropbox Deeplink.app**, menu-bar only, no Dock icon. "Set Team Dropbox Folder..." picks
  your local synced copy of the shared team folder. Registers the `dbxopen://` URL
  scheme: clicking a `dbxopen://...` link resolves it against your team folder and
  reveals the file in Finder. Shows an alert (not a silent no-op) if the file can't be
  found locally.
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

1. Click the menu-bar icon, "Set Team Dropbox Folder...", pick your local synced copy
   of the shared team folder.
2. Click any `dbxopen://...` link (Slack, wiki, wherever). Finder reveals the file.
3. Or: right-click any file in that folder in Finder, "Copy Dropbox Deeplink".

## Known limits (v1)

- macOS only.
- The right-click action currently appears on every file in Finder, not just files
  inside your Team Dropbox Folder. Clicking it on a file outside that folder shows a
  clear error instead of copying a broken link. Restricting *where the menu item shows
  up* to just the team folder isn't possible with a Finder Quick Action (Apple's
  Services menu matches by file type, not by location); it would require a Finder Sync
  Extension instead, a bigger build. Open item if this becomes a real annoyance.
- Multiple Dropbox accounts on one machine: not handled specially, the folder picker
  sidesteps it since you browse to the actual folder regardless of account.
- Assumes everyone's synced copy of the team folder has the same relative structure.
