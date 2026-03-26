# New GitHub release: set `version` to the tag without the leading v, replace `sha256` with
#   shasum -a 256 QueuePaste.dmg
cask "queuepaste" do
  version "1.01"
  sha256 "ef3ab023764fd627e58d5d7505a4b0e50f99ea09ad1fd5a7f6c01307342cfc3e"

  url "https://github.com/tmarhguy/QueuePaste/releases/download/v#{version}/QueuePaste.dmg"
  name "QueuePaste"
  desc "Sequentially paste items from a loaded list with a global hotkey"
  homepage "https://github.com/tmarhguy/QueuePaste"

  depends_on macos: ">= :ventura"

  app "QueuePaste.app"

  zap trash: [
    "~/Library/Application Support/QueuePaste",
    "~/Library/Preferences/tmarhguy.QueuePaste.plist",
  ]
end
