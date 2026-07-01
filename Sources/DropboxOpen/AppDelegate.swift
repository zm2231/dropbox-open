import Cocoa
import DropboxOpenCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pendingURL: URL?
    private var finderExtensionStatus: FinderExtensionStatus = .notFound

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        refreshFinderExtensionStatus()
        buildStatusItem()
    }

    private func buildStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        }
        statusItem?.button?.image = statusIcon()

        let menu = NSMenu()

        let doctorItem = NSMenuItem(title: finderExtensionStatus.menuLabel, action: #selector(showFinderExtensionDoctor), keyEquivalent: "")
        doctorItem.target = self
        doctorItem.image = finderExtensionStatus.isUsable ? nil : NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        menu.addItem(doctorItem)
        menu.addItem(.separator())

        let addWorkspaceItem = NSMenuItem(title: "Add Dropbox Workspace...", action: #selector(promptForWorkspaceRoot), keyEquivalent: "")
        addWorkspaceItem.target = self
        menu.addItem(addWorkspaceItem)

        let statusLine = NSMenuItem(title: workspaceStatusLabel(), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        for workspace in Config.workspaces {
            let item = NSMenuItem(title: "\(workspace.id): \(workspace.rootPath)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        let clearItem = NSMenuItem(title: "Clear Workspaces...", action: #selector(confirmClearWorkspaces), keyEquivalent: "")
        clearItem.target = self
        clearItem.isEnabled = !Config.workspaces.isEmpty
        menu.addItem(clearItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
    }

    private func statusIcon() -> NSImage {
        if finderExtensionStatus.isUsable {
            return BoxIcon.make(accessibilityDescription: "Dropbox Deeplink")
        }

        let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Dropbox Deeplink needs attention")
            ?? BoxIcon.make(accessibilityDescription: "Dropbox Deeplink needs attention")
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func refreshFinderExtensionStatus() {
        finderExtensionStatus = FinderExtensionDoctor.status()
    }

    private func workspaceStatusLabel() -> String {
        let count = Config.workspaces.count
        switch count {
        case 0:
            return "Workspaces: none set"
        case 1:
            return "Workspaces: 1 configured"
        default:
            return "Workspaces: \(count) configured"
        }
    }

    private func refreshMenu() {
        buildStatusItem()
    }

    @objc private func promptForWorkspaceRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Pick the local Dropbox folder this app should treat as the source of truth."
        panel.prompt = "Add Workspace"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let workspace = Config.addWorkspace(rootURL: url)
        refreshMenu()

        showAlert(
            title: "Workspace added",
            message: "Links copied from this folder will use:\n\ndbxopen://\(workspace.id)/...\n\nTiny bit of ceremony. Dropbox made us do it."
        )

        if let pending = pendingURL {
            pendingURL = nil
            reveal(relativePath: pending)
        }
    }

    @objc private func confirmClearWorkspaces() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = appAlertIcon()
        alert.alertStyle = .warning
        alert.messageText = "Clear Dropbox workspaces?"
        alert.informativeText = "Existing dbxopen:// links will stop resolving until you add the matching workspace again. Very dramatic, very reversible."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Config.clearWorkspaces()
        refreshMenu()
    }

    @objc private func showFinderExtensionDoctor() {
        refreshFinderExtensionStatus()
        guard !finderExtensionStatus.isUsable else {
            showAlert(title: "Finder extension enabled", message: "Finder says the extension is on. Right-click actions should appear for files inside configured Dropbox workspaces.")
            return
        }

        let alert = NSAlert()
        alert.icon = appAlertIcon()
        alert.alertStyle = .warning
        alert.messageText = finderExtensionStatus.menuLabel
        alert.informativeText = "The right-click action needs the Finder Sync extension. The app can ask macOS to enable it now; if Finder still acts surprised, enable \"Dropbox Deeplink Finder Extension\" in System Settings > Login Items & Extensions > Finder Extensions."
        alert.addButton(withTitle: "Enable Extension")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        finderExtensionStatus = FinderExtensionDoctor.enable()
        refreshMenu()
        if finderExtensionStatus.isUsable {
            showAlert(title: "Finder extension enabled", message: "Finder may need a moment to remember it has a job. Right-click actions should appear inside configured Dropbox workspaces.")
        } else {
            showAlert(title: finderExtensionStatus.menuLabel, message: "macOS still reports the Finder extension as unavailable. Manual checkbox time: System Settings > Login Items & Extensions > Finder Extensions.")
        }
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        reveal(relativePath: url)
    }

    private func reveal(relativePath url: URL) {
        if Config.workspaces.isEmpty {
            pendingURL = url
            promptForWorkspaceRoot()
            return
        }

        let resolved: ResolvedDropboxLink
        do {
            resolved = try Config.store.resolve(url)
        } catch {
            showAlert(title: "Can't open Dropbox link", message: "\(error.localizedDescription)\n\nThe link is only magic if this Mac knows the matching workspace.")
            return
        }

        guard FileManager.default.fileExists(atPath: resolved.fileURL.path) else {
            showAlert(title: "File not found", message: "Tried: \(resolved.fileURL.path)\n\nEither Dropbox has not synced it yet, or workspace '\(resolved.workspace.id)' points at the wrong local folder. Both are annoying. Only one is this app's fault.")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([resolved.fileURL])
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.icon = appAlertIcon()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func appAlertIcon() -> NSImage {
        BoxIcon.makeAlertIcon(accessibilityDescription: "Dropbox Deeplink")
    }

}
