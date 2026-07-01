cask "dropbox-open" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/zm2231/dropbox-open/releases/download/v#{version}/Dropbox%20Deeplink.zip"
  name "Dropbox Deeplink"
  desc "Menu-bar app that resolves dbxopen:// links to a local Finder reveal"
  homepage "https://github.com/zm2231/dropbox-open"

  app "Dropbox Deeplink.app"
  artifact "Copy Dropbox Deeplink.workflow",
           target: "#{Dir.home}/Library/Services/Copy Dropbox Deeplink.workflow"

  postflight do
    system_command "/usr/bin/open",
                    args: ["-g", "-j", "#{appdir}/Dropbox Deeplink.app"]
    system_command "/System/Library/CoreServices/pbs",
                    args: ["-flush"]
  end

  zap trash: [
    "~/Library/Preferences/com.quoxient.dropbox-open.plist",
    "~/Library/Services/Copy Dropbox Deeplink.workflow",
  ]
end
