import Foundation

public struct Workspace: Codable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var rootPath: String

    public init(id: String, name: String, rootPath: String) {
        self.id = Workspace.normalizedID(id)
        self.name = name
        self.rootPath = Workspace.normalizedPath(rootPath)
    }

    public var rootURL: URL {
        URL(fileURLWithPath: rootPath, isDirectory: true)
    }

    public static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    public static func normalizedID(_ value: String) -> String {
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var output = ""
        var lastWasDash = false

        for scalar in lower.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                output.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                output.append("-")
                lastWasDash = true
            }
        }

        let trimmed = output.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "workspace" : trimmed
    }
}

public struct ResolvedDropboxLink: Equatable {
    public var workspace: Workspace
    public var relativePath: String
    public var fileURL: URL
}

public enum DropboxLinkError: LocalizedError, Equatable {
    case unsupportedScheme
    case noWorkspaces
    case unknownWorkspace(String)
    case ambiguousLegacyLink
    case unsafeRelativePath(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedScheme:
            return "That link is not a dbxopen:// link."
        case .noWorkspaces:
            return "No Dropbox workspaces are configured yet."
        case .unknownWorkspace(let id):
            return "No Dropbox workspace is configured for '\(id)'."
        case .ambiguousLegacyLink:
            return "That legacy link does not name a workspace, and more than one workspace is configured."
        case .unsafeRelativePath(let path):
            return "The link path is not safe to open: \(path)"
        }
    }
}

public final class WorkspaceStore {
    public static let appSuiteName = "com.quoxient.dropbox-open"
    public static let appGroupSuiteName = "group.com.quoxient.dropbox-open"
    public static let workspacesDidChangeNotification = Notification.Name("com.quoxient.dropbox-open.workspacesChanged")
    public static let workspacesKey = "workspacesJSON"
    public static let defaultWorkspaceIDKey = "defaultWorkspaceID"
    public static let legacyTeamRootKey = "teamRootPath"

    private let defaults: UserDefaults
    private let mirrorDefaults: [UserDefaults]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard, mirrorDefaults: [UserDefaults] = []) {
        self.defaults = defaults
        self.mirrorDefaults = mirrorDefaults
    }

    public static func sharedDefaults() -> UserDefaults {
        let appDefaults = UserDefaults(suiteName: appSuiteName) ?? .standard
        guard let group = UserDefaults(suiteName: appGroupSuiteName) else {
            return appDefaults
        }

        migrateSharedDefaults(from: appDefaults, to: group)
        migrateSharedDefaults(from: .standard, to: group)
        migrateSharedDefaults(from: group, to: appDefaults)
        return group
    }

    public static func sharedStore() -> WorkspaceStore {
        let appDefaults = UserDefaults(suiteName: appSuiteName) ?? .standard
        return WorkspaceStore(defaults: sharedDefaults(), mirrorDefaults: [appDefaults])
    }

    public static func migrateSharedDefaults(from standard: UserDefaults, to group: UserDefaults) {
        standard.synchronize()
        group.synchronize()

        normalizeStoredWorkspaces(in: standard)
        normalizeStoredWorkspaces(in: group)

        if group.string(forKey: workspacesKey) == nil,
           let existing = standard.string(forKey: workspacesKey) {
            group.set(normalizedWorkspaceJSON(from: existing) ?? existing, forKey: workspacesKey)
        }
        if let existing = standard.string(forKey: workspacesKey),
           workspaceCount(in: existing) > workspaceCount(in: group.string(forKey: workspacesKey)) {
            group.set(normalizedWorkspaceJSON(from: existing) ?? existing, forKey: workspacesKey)
            if let defaultID = standard.string(forKey: defaultWorkspaceIDKey) {
                group.set(defaultID, forKey: defaultWorkspaceIDKey)
            }
            if let legacyPath = standard.string(forKey: legacyTeamRootKey) {
                group.set(legacyPath, forKey: legacyTeamRootKey)
            }
        }
        if group.string(forKey: defaultWorkspaceIDKey) == nil,
           let existing = standard.string(forKey: defaultWorkspaceIDKey) {
            group.set(existing, forKey: defaultWorkspaceIDKey)
        }
        if group.string(forKey: legacyTeamRootKey) == nil,
           let existing = standard.string(forKey: legacyTeamRootKey) {
            group.set(existing, forKey: legacyTeamRootKey)
        }
        group.synchronize()
    }

    public var workspaces: [Workspace] {
        get {
            defaults.synchronize()
            if let data = defaults.string(forKey: Self.workspacesKey)?.data(using: .utf8),
               let decoded = try? decoder.decode([Workspace].self, from: data) {
                let normalized = Self.normalizedWorkspaces(decoded)
                if normalized != decoded {
                    save(workspaces: normalized, defaultWorkspaceID: normalized.first?.id, preserveLegacyRoot: false)
                }
                return normalized
            }

            guard let legacyPath = defaults.string(forKey: Self.legacyTeamRootKey), !legacyPath.isEmpty else {
                return []
            }

            let legacy = Workspace(
                id: uniqueID(base: Workspace.normalizedID(URL(fileURLWithPath: legacyPath).lastPathComponent), excluding: []),
                name: URL(fileURLWithPath: legacyPath).lastPathComponent,
                rootPath: legacyPath
            )
            save(workspaces: [legacy], defaultWorkspaceID: legacy.id, preserveLegacyRoot: true)
            return [legacy]
        }
        set {
            let defaultID = newValue.first(where: { $0.id == defaultWorkspaceID })?.id ?? newValue.first?.id
            save(workspaces: newValue, defaultWorkspaceID: defaultID, preserveLegacyRoot: false)
        }
    }

    public var defaultWorkspaceID: String? {
        defaults.string(forKey: Self.defaultWorkspaceIDKey)
    }

    public var defaultWorkspace: Workspace? {
        let all = workspaces
        if let id = defaultWorkspaceID, let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }

    public func addWorkspace(rootURL: URL, name explicitName: String? = nil) -> Workspace {
        var all = workspaces
        let rootPath = Workspace.normalizedPath(rootURL.path)
        if let existingParent = all
            .sorted(by: { $0.rootPath.count > $1.rootPath.count })
            .first(where: { rootPath == $0.rootPath || rootPath.hasPrefix($0.rootPath + "/") }) {
            return existingParent
        }

        let name = explicitName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ?? rootURL.lastPathComponent.nonEmpty
            ?? "Workspace"
        let existingIDs = Set(all.map(\.id))
        let id = uniqueID(base: Workspace.normalizedID(name), excluding: existingIDs)
        let workspace = Workspace(id: id, name: name, rootPath: rootPath)

        all.removeAll {
            $0.rootPath == rootPath ||
                $0.rootPath.hasPrefix(rootPath + "/") ||
                $0.id == id
        }
        all.append(workspace)
        save(workspaces: all, defaultWorkspaceID: defaultWorkspaceID ?? workspace.id, preserveLegacyRoot: false)
        return workspace
    }

    public func clearWorkspaces() {
        save(workspaces: [], defaultWorkspaceID: nil, preserveLegacyRoot: false)
    }

    public func link(for fileURL: URL) -> String? {
        guard let match = matchWorkspace(for: fileURL) else { return nil }
        let encoded = Self.encodePath(match.relativePath)
        if encoded.isEmpty {
            return "dbxopen://\(match.workspace.id)/"
        }
        return "dbxopen://\(match.workspace.id)/\(encoded)"
    }

    public func resolve(_ url: URL) throws -> ResolvedDropboxLink {
        guard url.scheme == "dbxopen" else { throw DropboxLinkError.unsupportedScheme }
        let all = workspaces
        guard !all.isEmpty else { throw DropboxLinkError.noWorkspaces }

        if let rawHost = url.host, let host = rawHost.removingPercentEncoding {
            if let workspace = all.first(where: { $0.id == host }) {
                let relative = Self.decodePath(String(url.path.dropFirst()))
                return try resolved(workspace: workspace, relativePath: relative)
            }
            if !url.path.isEmpty {
                throw DropboxLinkError.unknownWorkspace(host)
            }
        }

        let legacy = Self.decodePath((url.host ?? "") + url.path)
        guard let workspace = defaultWorkspace ?? (all.count == 1 ? all[0] : nil) else {
            throw DropboxLinkError.ambiguousLegacyLink
        }
        return try resolved(workspace: workspace, relativePath: legacy)
    }

    public func matchWorkspace(for fileURL: URL) -> ResolvedDropboxLink? {
        let filePath = fileURL.standardizedFileURL.path
        let matches = workspaces.compactMap { workspace -> ResolvedDropboxLink? in
            let root = workspace.rootPath
            guard filePath == root || filePath.hasPrefix(root + "/") else { return nil }
            let relative = filePath == root ? "" : String(filePath.dropFirst(root.count + 1))
            return ResolvedDropboxLink(workspace: workspace, relativePath: relative, fileURL: fileURL)
        }
        return matches.sorted { $0.workspace.rootPath.count > $1.workspace.rootPath.count }.first
    }

    public static func encodePath(_ relativePath: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "?#")
        return relativePath.addingPercentEncoding(withAllowedCharacters: allowed) ?? relativePath
    }

    public static func decodePath(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private func resolved(workspace: Workspace, relativePath: String) throws -> ResolvedDropboxLink {
        try validate(relativePath: relativePath)
        let fileURL = workspace.rootURL.appendingPathComponent(relativePath)
        return ResolvedDropboxLink(workspace: workspace, relativePath: relativePath, fileURL: fileURL)
    }

    private func validate(relativePath: String) throws {
        if relativePath.hasPrefix("/") {
            throw DropboxLinkError.unsafeRelativePath(relativePath)
        }
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        if parts.contains("..") {
            throw DropboxLinkError.unsafeRelativePath(relativePath)
        }
    }

    private func save(workspaces: [Workspace], defaultWorkspaceID: String?, preserveLegacyRoot: Bool) {
        save(
            workspaces: workspaces,
            defaultWorkspaceID: defaultWorkspaceID,
            preserveLegacyRoot: preserveLegacyRoot,
            to: defaults
        )
        for mirror in mirrorDefaults {
            save(
                workspaces: workspaces,
                defaultWorkspaceID: defaultWorkspaceID,
                preserveLegacyRoot: preserveLegacyRoot,
                to: mirror
            )
        }
    }

    private func save(
        workspaces: [Workspace],
        defaultWorkspaceID: String?,
        preserveLegacyRoot: Bool,
        to defaults: UserDefaults
    ) {
        if let data = try? encoder.encode(workspaces),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: Self.workspacesKey)
        }
        defaults.set(defaultWorkspaceID, forKey: Self.defaultWorkspaceIDKey)
        if preserveLegacyRoot {
            defaults.synchronize()
            return
        }
        if let defaultWorkspace = workspaces.first(where: { $0.id == defaultWorkspaceID }) ?? workspaces.first {
            defaults.set(defaultWorkspace.rootPath, forKey: Self.legacyTeamRootKey)
        } else {
            defaults.removeObject(forKey: Self.legacyTeamRootKey)
        }
        defaults.synchronize()
    }

    private func uniqueID(base: String, excluding existing: Set<String>) -> String {
        var candidate = base
        var index = 2
        while existing.contains(candidate) {
            candidate = "\(base)-\(index)"
            index += 1
        }
        return candidate
    }

    private static func workspaceCount(in json: String?) -> Int {
        guard let json, let data = json.data(using: .utf8) else { return 0 }
        guard let decoded = try? JSONDecoder().decode([Workspace].self, from: data) else { return 0 }
        return normalizedWorkspaces(decoded).count
    }

    private static func normalizeStoredWorkspaces(in defaults: UserDefaults) {
        guard let json = defaults.string(forKey: workspacesKey),
              let normalized = normalizedWorkspaceJSON(from: json),
              normalized != json else { return }
        defaults.set(normalized, forKey: workspacesKey)
        defaults.synchronize()
    }

    private static func normalizedWorkspaceJSON(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([Workspace].self, from: data),
              let normalizedData = try? JSONEncoder().encode(normalizedWorkspaces(decoded)) else {
            return nil
        }
        return String(data: normalizedData, encoding: .utf8)
    }

    private static func normalizedWorkspaces(_ workspaces: [Workspace]) -> [Workspace] {
        var normalized: [Workspace] = []
        for workspace in workspaces.sorted(by: { $0.rootPath.count < $1.rootPath.count }) {
            guard normalized.first(where: { workspace.rootPath == $0.rootPath || workspace.rootPath.hasPrefix($0.rootPath + "/") }) == nil else {
                continue
            }
            normalized.removeAll { $0.rootPath.hasPrefix(workspace.rootPath + "/") }
            normalized.append(workspace)
        }
        return normalized
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
