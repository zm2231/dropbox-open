import AppKit

public enum BoxIcon {
    public static func make(accessibilityDescription: String?) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            let body = NSBezierPath(roundedRect: NSRect(x: 3.0, y: 3.0, width: 12.0, height: 10.0), xRadius: 1.8, yRadius: 1.8)
            body.fill()

            let lid = NSBezierPath()
            lid.move(to: NSPoint(x: 3.8, y: 12.0))
            lid.line(to: NSPoint(x: 7.0, y: 15.2))
            lid.line(to: NSPoint(x: 10.8, y: 15.2))
            lid.line(to: NSPoint(x: 14.2, y: 12.0))
            lid.line(to: NSPoint(x: 11.6, y: 9.4))
            lid.line(to: NSPoint(x: 9.0, y: 12.0))
            lid.line(to: NSPoint(x: 6.4, y: 9.4))
            lid.close()
            lid.fill()
            return true
        }
        image.accessibilityDescription = accessibilityDescription
        image.isTemplate = true
        return image
    }
}
