import Cocoa
import FinderSync
import os

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.quoxient.dropbox-open", category: "FinderSync")
    private let store = WorkspaceStore(defaults: WorkspaceStore.sharedDefaults())

    override init() {
        super.init()
        logger.notice("Finder Sync extension initialized")
        updateDirectoryURLs()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(workspacesDidChange),
            name: WorkspaceStore.workspacesDidChangeNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    override var toolbarItemName: String {
        "Dropbox Deeplink"
    }

    override var toolbarItemToolTip: String {
        "Copy a dbxopen:// link for the selected Dropbox item"
    }

    override var toolbarItemImage: NSImage {
        BoxIcon.make(accessibilityDescription: "Dropbox Deeplink")
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let urls = candidateURLs(for: menuKind)
        let supported = urls.filter { store.matchWorkspace(for: $0) != nil }
        logger.notice("Finder menu requested kind=\(String(describing: menuKind), privacy: .public) candidates=\(urls.map(\.path).joined(separator: " | "), privacy: .public) supported=\(supported.map(\.path).joined(separator: " | "), privacy: .public)")
        guard !supported.isEmpty else { return nil }

        let menu = NSMenu(title: "Dropbox Deeplink")
        let item = NSMenuItem(
            title: supported.count == 1 ? "Copy Dropbox Deeplink" : "Copy Dropbox Deeplinks",
            action: #selector(copyDropboxLinks(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = BoxIcon.make(accessibilityDescription: nil)
        item.representedObject = supported
        menu.addItem(item)
        return menu
    }

    @objc private func copyDropboxLinks(_ sender: NSMenuItem) {
        let urls = (sender.representedObject as? [URL]) ?? candidateURLs(for: .contextualMenuForItems)
        let links = urls.compactMap { store.link(for: $0) }
        logger.notice("Copy requested urls=\(urls.map(\.path).joined(separator: " | "), privacy: .public) links=\(links.count, privacy: .public)")
        guard !links.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(links.joined(separator: "\n"), forType: .string)
    }

    @objc private func workspacesDidChange() {
        updateDirectoryURLs()
    }

    private func updateDirectoryURLs() {
        let urls = Set(store.workspaces.map(\.rootURL))
        FIFinderSyncController.default().directoryURLs = urls
        logger.notice("Directory URLs updated: \(urls.map(\.path).sorted().joined(separator: " | "), privacy: .public)")
    }

    private func candidateURLs(for menuKind: FIMenuKind) -> [URL] {
        let controller = FIFinderSyncController.default()
        switch menuKind {
        case .contextualMenuForItems, .toolbarItemMenu:
            if let selected = controller.selectedItemURLs(), !selected.isEmpty {
                return selected
            }
            return controller.targetedURL().map { [$0] } ?? []
        case .contextualMenuForContainer, .contextualMenuForSidebar:
            return controller.targetedURL().map { [$0] } ?? []
        @unknown default:
            return controller.selectedItemURLs() ?? []
        }
    }

}
