cask "dropbox-open" do
  version "1.0"
  sha256 "7be16b8f19b620ce59cf82fc3c68521ef5154066932a0419012e4efe18e784ff"

  url "https://github.com/zm2231/dropbox-open/releases/download/v#{version}/Dropbox.Deeplink.zip"
  name "Dropbox Deeplink"
  desc "Menu-bar app that resolves dbxopen:// links to a local Finder reveal"
  homepage "https://github.com/zm2231/dropbox-open"

  app "Dropbox Deeplink.app"

  postflight do
    system_command "/bin/rm",
                    args: ["-rf", "#{Dir.home}/Library/Services/Copy Dropbox Deeplink.workflow"],
                    sudo: false
    system_command "/System/Library/CoreServices/pbs",
                    args: ["-flush"],
                    sudo: false
    system_command "/usr/bin/open",
                    args: ["-g", "-j", "#{appdir}/Dropbox Deeplink.app"]
    system_command "/usr/bin/pluginkit",
                    args: ["-a", "#{appdir}/Dropbox Deeplink.app/Contents/PlugIns/DropboxOpenFinderSync.appex"],
                    sudo: false
    system_command "/usr/bin/pluginkit",
                    args: ["-e", "use", "-i", "com.merchantry.dropbox-open.findersync"],
                    sudo: false
    system_command "/usr/bin/killall",
                    args: ["Finder"],
                    sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.merchantry.dropbox-open.plist",
    "~/Library/Services/Copy Dropbox Deeplink.workflow",
  ]
end
