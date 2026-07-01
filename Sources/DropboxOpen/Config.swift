import Foundation
import DropboxOpenCore

enum Config {
    static let store = WorkspaceStore(defaults: WorkspaceStore.sharedDefaults())

    static var teamRoot: URL? {
        get {
            store.defaultWorkspace?.rootURL
        }
        set {
            guard let newValue else {
                store.clearWorkspaces()
                return
            }
            _ = store.addWorkspace(rootURL: newValue)
        }
    }

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
