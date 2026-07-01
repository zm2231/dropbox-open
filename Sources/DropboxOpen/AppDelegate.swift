import Cocoa
import DropboxOpenCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pendingURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        buildStatusItem()
    }

    private func buildStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            statusItem?.button?.image = BoxIcon.make(accessibilityDescription: "Dropbox Deeplink")
        }

        let menu = NSMenu()

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
        panel.message = "Select a local synced Dropbox workspace folder"
        panel.prompt = "Add Workspace"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let workspace = Config.addWorkspace(rootURL: url)
        refreshMenu()

        showAlert(
            title: "Workspace added",
            message: "Links copied from this folder will use:\n\ndbxopen://\(workspace.id)/..."
        )

        if let pending = pendingURL {
            pendingURL = nil
            reveal(relativePath: pending)
        }
    }

    @objc private func confirmClearWorkspaces() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Clear Dropbox workspaces?"
        alert.informativeText = "Existing dbxopen:// links will stop resolving until you add the matching workspace again."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Config.clearWorkspaces()
        refreshMenu()
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
            showAlert(title: "Can't open Dropbox link", message: error.localizedDescription)
            return
        }

        guard FileManager.default.fileExists(atPath: resolved.fileURL.path) else {
            showAlert(title: "File not found", message: "Tried: \(resolved.fileURL.path)\n\nMake sure this file has finished syncing, or that workspace '\(resolved.workspace.id)' points at the right local folder.")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([resolved.fileURL])
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

}
