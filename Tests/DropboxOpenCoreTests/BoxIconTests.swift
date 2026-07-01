import AppKit
import Testing
@testable import DropboxOpenCore

@Suite("BoxIcon")
struct BoxIconTests {
    @Test("creates a fixed-size template icon")
    func createsTemplateIcon() {
        let icon = BoxIcon.make(accessibilityDescription: "Dropbox Deeplink")

        #expect(icon.isTemplate)
        #expect(icon.size == NSSize(width: 18, height: 18))
        #expect(icon.accessibilityDescription == "Dropbox Deeplink")
        #expect(!icon.representations.isEmpty)
    }

    @Test("creates explicitly tinted icon for Finder menus")
    func createsTintedIcon() {
        let icon = BoxIcon.make(accessibilityDescription: nil, tint: .white)

        #expect(!icon.isTemplate)
        #expect(icon.size == NSSize(width: 18, height: 18))
        #expect(!icon.representations.isEmpty)
    }
}
