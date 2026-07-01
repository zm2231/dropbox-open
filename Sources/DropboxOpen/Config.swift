import Foundation

enum Config {
    private static let key = "teamRootPath"

    static var teamRoot: URL? {
        get {
            guard let path = UserDefaults.standard.string(forKey: key) else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            UserDefaults.standard.set(newValue?.path, forKey: key)
        }
    }
}
