import Cocoa
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let store = WorkspaceStore(defaults: WorkspaceStore.sharedDefaults())

    override init() {
        super.init()
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
        NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "Dropbox Deeplink") ?? NSImage()
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let urls = candidateURLs(for: menuKind)
        let supported = urls.filter { store.matchWorkspace(for: $0) != nil }
        guard !supported.isEmpty else { return nil }

        let menu = NSMenu(title: "Dropbox Deeplink")
        let item = NSMenuItem(
            title: supported.count == 1 ? "Copy Dropbox Deeplink" : "Copy Dropbox Deeplinks",
            action: #selector(copyDropboxLinks(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        item.representedObject = supported
        menu.addItem(item)
        return menu
    }

    @objc private func copyDropboxLinks(_ sender: NSMenuItem) {
        let urls = (sender.representedObject as? [URL]) ?? candidateURLs(for: .contextualMenuForItems)
        let links = urls.compactMap { store.link(for: $0) }
        guard !links.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(links.joined(separator: "\n"), forType: .string)
    }

    @objc private func workspacesDidChange() {
        updateDirectoryURLs()
    }

    private func updateDirectoryURLs() {
        FIFinderSyncController.default().directoryURLs = Set(store.workspaces.map(\.rootURL))
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
