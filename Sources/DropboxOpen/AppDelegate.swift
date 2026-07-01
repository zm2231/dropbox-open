import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Dropbox Deeplink")

        let menu = NSMenu()

        let setRootItem = NSMenuItem(title: "Set Team Dropbox Folder...", action: #selector(promptForTeamRoot), keyEquivalent: "")
        setRootItem.target = self
        menu.addItem(setRootItem)

        let statusLine = NSMenuItem(title: teamRootStatusLabel(), action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    private func teamRootStatusLabel() -> String {
        guard let root = Config.teamRoot else { return "Team Folder: not set" }
        return "Team Folder: \(root.path)"
    }

    private func refreshStatusLine() {
        guard let menu = statusItem.menu, menu.items.count > 1 else { return }
        menu.items[1].title = teamRootStatusLabel()
    }

    @objc private func promptForTeamRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select the local folder that holds your synced copy of the team Dropbox folder"
        panel.prompt = "Set Team Folder"

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Config.teamRoot = url
        refreshStatusLine()

        if let pending = pendingURL {
            pendingURL = nil
            reveal(relativePath: pending)
        }
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        reveal(relativePath: url)
    }

    private func reveal(relativePath url: URL) {
        guard let root = Config.teamRoot else {
            pendingURL = url
            promptForTeamRoot()
            return
        }

        let relative = (url.host ?? "") + url.path
        let decoded = relative.removingPercentEncoding ?? relative
        let resolved = root.appendingPathComponent(decoded)

        guard FileManager.default.fileExists(atPath: resolved.path) else {
            showAlert(title: "File not found", message: "Tried: \(resolved.path)\n\nMake sure this file has finished syncing, or that your Team Dropbox Folder is set correctly.")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([resolved])
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
