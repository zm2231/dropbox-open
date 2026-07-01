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
- **Finder Sync Extension**, embedded inside the app. Finder asks it for contextual
  menus only inside configured workspace folders, so the "Copy Dropbox Deeplink"
  item is scoped to the right locations and can use its own menu icon/grouping.

## Build

```
./Scripts/build-app.sh
```

Produces a signed, notarized `dist/Dropbox Deeplink.app` and `dist/Dropbox Deeplink.zip`.
The default notarization profile is `dropbox-open-notary`; override it with
`NOTARY_PROFILE=...`. For local packaging checks that should skip Apple's notary
service, run `NOTARIZE=0 ./Scripts/build-app.sh`.

Before the first release build on a new machine, create the Keychain profile:

```
xcrun notarytool store-credentials dropbox-open-notary \
  --apple-id you@example.com \
  --team-id Q5Y75DVV4M
```

`notarytool` will securely prompt for an app-specific password and validate the
profile before saving it.

## Install (once released)

```
brew tap zm2231/tap
brew install --cask dropbox-open
```

Installs the app into `/Applications`. The Finder Sync extension is embedded in the
app bundle; macOS may ask you to enable it in System Settings the first time. The
app also registers as a login item on launch so `dbxopen://` links keep working
after logout or reboot; macOS may ask you to allow this background item.

## Use

1. Click the menu-bar icon, "Add Dropbox Workspace...", pick your local synced copy
   of a shared Dropbox folder. The app assigns a workspace id from the folder name
   (for example `Quoxient` becomes `quoxient`).
2. Click any `dbxopen://...` link (Slack, wiki, wherever). Finder reveals the file.
3. Or: right-click any file in a configured workspace in Finder, "Copy Dropbox
   Deeplink". If more than one workspace matches, the deepest/longest workspace root
   wins. The Finder extension also exposes a toolbar menu for selected workspace
   files when the extension is enabled.

New links include the workspace id:

```
dbxopen://quoxient/Reports/2026-05-09-research-pass2-generational-psychology.md
```

Older single-root links like `dbxopen://Reports%2Ffile.md` still resolve against the
default workspace.

## Finder integration

Dropbox Deeplink ships a `com.apple.FinderSync` extension rather than an Automator
Service. That is what gives it folder-scoped visibility, custom menu icons, and a
Finder toolbar menu. The menu-bar app and Finder extension share workspace config
through the app group `group.com.quoxient.dropbox-open`.

If Finder does not show the menu item after install, enable "Dropbox Deeplink Finder
Extension" in System Settings > Login Items & Extensions > Finder Extensions. The
Finder extension is only reliable when the app is installed in `/Applications`;
remove any older copy from `~/Applications` so PlugInKit does not point Finder at
the wrong bundle.

## Known limits

- macOS only.
- Finder extension activation is controlled by macOS. If the extension is disabled,
  links still open through the menu-bar app, but Finder won't show the contextual
  copy item until the extension is enabled again.
- Multiple Dropbox accounts on one machine are supported by adding one workspace root
  per synced shared folder. Links require teammates to use the same workspace id.
- Assumes everyone's synced copy of each workspace has the same relative structure.
