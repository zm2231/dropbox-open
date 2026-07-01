import AppKit

public enum BoxIcon {
    private static let symbolName = "shippingbox.fill"
    private static let fallbackSymbolName = "shippingbox"
    private static let size = NSSize(width: 18, height: 18)

    public static func make(accessibilityDescription: String?) -> NSImage {
        make(accessibilityDescription: accessibilityDescription, tint: nil)
    }

    public static func makeForCurrentAppearance(accessibilityDescription: String?) -> NSImage {
        make(accessibilityDescription: accessibilityDescription, tint: isDarkAppearance() ? .white : .black)
    }

    public static func make(accessibilityDescription: String?, tint: NSColor?) -> NSImage {
        guard let symbol = symbol(accessibilityDescription: accessibilityDescription) else {
            return NSImage()
        }

        guard let tint else {
            symbol.isTemplate = true
            return symbol
        }

        let image = NSImage(size: size, flipped: false) { rect in
            tint.setFill()
            rect.fill()
            symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        image.accessibilityDescription = accessibilityDescription
        image.isTemplate = false
        return image
    }

    private static func symbol(accessibilityDescription: String?) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            ?? NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: accessibilityDescription)
        let configured = image?.withSymbolConfiguration(configuration) ?? image
        configured?.size = size
        configured?.accessibilityDescription = accessibilityDescription
        return configured
    }

    private static func isDarkAppearance() -> Bool {
        if NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        }
        if NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        }
        return UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}
