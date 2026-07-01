import Foundation
import Testing
@testable import DropboxOpenCore

@Suite("WorkspaceStore")
struct WorkspaceStoreTests {
    @Test("creates workspace-qualified links with longest root match")
    func createsQualifiedLinks() throws {
        let defaults = try isolatedDefaults()
        let store = WorkspaceStore(defaults: defaults)
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team"), name: "Team")
        _ = store.addWorkspace(rootURL: URL(fileURLWithPath: "/Dropbox/Team/Reports"), name: "Reports")

        let link = store.link(for: URL(fileURLWithPath: "/Dropbox/Team/Reports/2026/file name.md"))

        #expect(link == "dbxopen://reports/2026/file%20name.md")
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
