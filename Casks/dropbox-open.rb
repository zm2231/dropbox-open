cask "dropbox-open" do
  version "2.0.0"
  sha256 :no_check

  url "https://github.com/zm2231/dropbox-open/releases/download/v#{version}/Dropbox%20Deeplink.zip"
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
                    args: ["-e", "use", "-i", "com.quoxient.dropbox-open.findersync"],
                    sudo: false
    system_command "/usr/bin/killall",
                    args: ["Finder"],
                    sudo: false
  end

  zap trash: [
    "~/Library/Preferences/com.quoxient.dropbox-open.plist",
    "~/Library/Services/Copy Dropbox Deeplink.workflow",
  ]
end
