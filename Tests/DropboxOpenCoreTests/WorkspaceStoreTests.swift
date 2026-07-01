import Foundation
import Testing
@testable import DropboxOpenCore

@Suite("WorkspaceStore")
struct WorkspaceStoreTests {
    @Test("creates workspace-qualified links for matching workspace")
    func createsQualifiedLinks() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Personal"), name: "Personal")

        let link = store.link(for: URL(fileURLWithPath: "/Dropbox/Personal/2026/file name.md"))

        #expect(link == "dbxopen://personal/2026/file%20name.md")
    }

    @Test("does not create nested child workspaces under an existing root")
    func ignoresNestedChildWorkspace() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")

        let workspace = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team/Reports"), name: "Reports")

        #expect(workspace.id == "team")
        #expect(store.workspaces.map(\.id) == ["team"])
        #expect(store.link(for: URL(fileURLWithPath: "/Dropbox/Team/Reports/file.md")) == "dbxopen://team/Reports/file.md")
    }

    @Test("parent workspace replaces existing nested child workspaces")
    func parentWorkspaceReplacesNestedChildren() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team/Reports"), name: "Reports")

        let workspace = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")

        #expect(workspace.id == "team")
        #expect(store.workspaces.map(\.id) == ["team"])
    }

    @Test("resolves workspace-qualified links")
    func resolvesQualifiedLinks() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")

        let resolved = try store.resolve(#require(URL(string: "dbxopen://team/Reports/file%20name.md")))

        #expect(resolved.fileURL.path == "/Dropbox/Team/Reports/file name.md")
    }

    @Test("migrates legacy root and resolves old links")
    func migratesLegacyRoot() throws {
        let defaults = try isolatedDefaults()
        defaults.set("/Dropbox/Quoxient", forKey: WorkspaceStore.legacyTeamRootKey)
        let store = WorkspaceStore(defaults: defaults)

        let resolved = try store.resolve(#require(URL(string: "dbxopen://Reports%2Ffile.md")))

        #expect(store.workspaces.map(\.id) == ["quoxient"])
        #expect(resolved.fileURL.path == "/Dropbox/Quoxient/Reports/file.md")
    }

    @Test("repairs stale app group defaults from richer standard defaults")
    func repairsStaleSharedDefaults() throws {
        let standard = try isolatedDefaults()
        let group = try isolatedDefaults()
        let standardStore = WorkspaceStore(defaults: standard)
        let groupStore = WorkspaceStore(defaults: group)

        _ = standardStore.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Quoxient"), name: "Quoxient")
        _ = standardStore.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Personal"), name: "Personal")
        _ = groupStore.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Quoxient"), name: "Quoxient")

        WorkspaceStore.migrateSharedDefaults(from: standard, to: group)

        #expect(groupStore.workspaces.map(\.id) == ["quoxient", "personal"])
    }

    @Test("mirrors saves and clears to legacy app defaults")
    func mirrorsSavesAndClears() throws {
        let group = try isolatedDefaults()
        let appDefaults = try isolatedDefaults()
        let groupStore = WorkspaceStore(defaults: group, mirrorDefaults: [appDefaults])
        let appStore = WorkspaceStore(defaults: appDefaults)

        _ = groupStore.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Quoxient"), name: "Quoxient")
        _ = groupStore.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Personal"), name: "Personal")

        #expect(appStore.workspaces.map(\.id) == ["quoxient", "personal"])

        groupStore.clearWorkspaces()

        #expect(groupStore.workspaces.isEmpty)
        #expect(appStore.workspaces.isEmpty)
        #expect(group.string(forKey: WorkspaceStore.legacyTeamRootKey) == nil)
        #expect(appDefaults.string(forKey: WorkspaceStore.legacyTeamRootKey) == nil)
    }

    @Test("normalizes previously saved nested workspaces")
    func normalizesSavedNestedWorkspaces() throws {
        let defaults = try isolatedDefaults()
        let encoded = try JSONEncoder().encode([
            Workspace(id: "quoxient", name: "Quoxient", rootPath: "/Dropbox/Quoxient"),
            Workspace(id: "reports", name: "Reports", rootPath: "/Dropbox/Quoxient/Reports"),
        ])
        defaults.set(String(data: encoded, encoding: .utf8), forKey: WorkspaceStore.workspacesKey)
        let store = WorkspaceStore(defaults: defaults)

        #expect(store.workspaces.map(\.id) == ["quoxient"])
        #expect(store.link(for: URL(fileURLWithPath: "/Dropbox/Quoxient/Reports/file.md")) == "dbxopen://quoxient/Reports/file.md")
    }

    @Test("rejects unknown workspace-qualified links")
    func rejectsUnknownWorkspaceQualifiedLinks() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")

        #expect(throws: DropboxLinkError.unknownWorkspace("other")) {
            _ = try store.resolve(#require(URL(string: "dbxopen://other/file.md")))
        }
    }

    @Test("rejects unsafe relative paths")
    func rejectsUnsafePaths() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")

        #expect(throws: DropboxLinkError.unsafeRelativePath("../secrets.md")) {
            _ = try store.resolve(#require(URL(string: "dbxopen://team/../secrets.md")))
        }
    }

    private func isolatedDefaults() throws -> UserDefaults {
        let name = "WorkspaceStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
