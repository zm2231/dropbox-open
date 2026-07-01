import Foundation
import DropboxOpenCore

enum Config {
    static let store = WorkspaceStore()

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
        store.addWorkspace(rootURL: rootURL)
    }

    static func clearWorkspaces() {
        store.clearWorkspaces()
    }
}
