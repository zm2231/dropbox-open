import Testing
@testable import DropboxOpenCore

@Suite("FinderExtensionStatus")
struct FinderExtensionStatusTests {
    @Test("parses enabled pluginkit output")
    func parsesEnabledOutput() {
        let output = """
        +    com.merchantry.dropbox-open.findersync(1.0) ABCD /Applications/Dropbox Deeplink.app/Contents/PlugIns/DropboxOpenFinderSync.appex
         (1 plug-in)
        """

        #expect(FinderExtensionStatus.parse(pluginkitOutput: output) == .enabled)
    }

    @Test("parses disabled pluginkit output")
    func parsesDisabledOutput() {
        let output = """
        -    com.merchantry.dropbox-open.findersync(1.0) ABCD /Applications/Dropbox Deeplink.app/Contents/PlugIns/DropboxOpenFinderSync.appex
         (1 plug-in)
        """

        #expect(FinderExtensionStatus.parse(pluginkitOutput: output) == .disabled)
    }

    @Test("parses missing pluginkit output")
    func parsesMissingOutput() {
        #expect(FinderExtensionStatus.parse(pluginkitOutput: "  (no matches)\n") == .notFound)
        #expect(FinderExtensionStatus.parse(pluginkitOutput: "") == .notFound)
    }
}
