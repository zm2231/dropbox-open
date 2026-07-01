import Foundation
import DropboxOpenCore

enum Config {
    static let store = WorkspaceStore.sharedStore()

    static var workspaces: [Workspace] {
        store.workspaces
    }

    static func addWorkspace(rootURL: URL) -> Workspace {
        let workspace = store.addWorkspace(rootURL: rootURL)
        notifyWorkspaceChange()
        return workspace
    }

    static func clearWorkspaces() {
        store.clearWorkspaces()
        notifyWorkspaceChange()
    }

    private static func notifyWorkspaceChange() {
        DistributedNotificationCenter.default().postNotificationName(
            WorkspaceStore.workspacesDidChangeNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
