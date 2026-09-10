import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "nostrDms"

    StyledText {
        width: parent.width
        text: "Nostr"
        font.pixelSize: Theme.fontSizeXLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Publish notes from the launcher (type \"n\" plus your text, e.g. \"n hello nostr\" and press Enter) and get desktop notifications for replies, reactions and zaps to your posts. Requires the \u201cnak\u201d CLI."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeMedium
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "nsec"
        label: "Private key (nsec)"
        description: "Your nsec1... secret key used to sign notes and to watch replies/zaps. Leave empty to fall back to nak's machine default key (see \"nak key default\" in a terminal)."
        placeholder: "nsec1..."
        defaultValue: ""
    }

    ListSettingWithInput {
        settingKey: "relays"
        label: "Relays"
        description: "Relay URLs to publish to and watch for notifications. One per row."
        defaultValue: [
            { relay: "wss://relay.damus.io" },
            { relay: "wss://nos.lol" },
            { relay: "wss://relay.snort.social" },
            { relay: "wss://relay.primal.net" }
        ]
        fields: [
            { id: "relay", label: "Relay", placeholder: "wss://relay.damus.io", width: 300, required: true }
        ]
    }

    StringSetting {
        settingKey: "linkBase"
        label: "Notification link"
        description: "Base URL opened when you click a notification. The event ID is appended. Known patterns:\n\u2022 njump.me \u2014 https://njump.me/\n\u2022 Primal \u2014 https://primal.net/e/\n\u2022 Ditto \u2014 https://ditto.pub/e/\n\u2022 Snort \u2014 https://snort.social/note/\n\u2022 Nover \u2014 https://nover.io/e/"
        placeholder: "https://njump.me/"
        defaultValue: "https://njump.me/"
    }

    SliderSetting {
        settingKey: "sinceDays"
        label: "Watch history"
        description: "How many days of past activity to load when the watcher starts."
        defaultValue: 7
        minimum: 1
        maximum: 30
        unit: " days"
    }

    ToggleSetting {
        settingKey: "watchReplies"
        label: "Replies & mentions"
        description: "Notify when someone replies to your posts or mentions you."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "watchReactions"
        label: "Reactions"
        description: "Notify when someone reacts to your posts."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "watchZaps"
        label: "Zaps"
        description: "Notify when your posts receive zaps. Sender resolves from the zap-request when available."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "showToasts"
        label: "Show notification toasts"
        description: "Show a desktop toast for each new event (in addition to the bar badge)."
        defaultValue: true
    }

    StringSetting {
        settingKey: "trigger"
        label: "Launcher trigger"
        description: "Prefix to start a post in the launcher, e.g. \"hello nostr\"."
        placeholder: "n"
        defaultValue: "n"
    }

    StyledText {
        width: parent.width
        text: "Account helpers"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        DankButton {
            text: "Copy pubkey"
            onClicked: {
                var sec = String(root.loadValue("nsec", "") || "").trim();
                var args = ["nak", "key", "public"];
                if (sec.length > 0) {
                    args.push(sec);
                }
                Proc.runCommand("nostr.pubkey", args, (stdout, exitCode) => {
                    if (exitCode === 0) {
                        var pk = String(stdout || "").trim();
                        if (pk.length > 0) {
                            Quickshell.execDetached(["dms", "cl", "copy", pk]);
                            ToastService.showInfo("Pubkey copied", pk.slice(0, 12) + "..." + pk.slice(-4));
                        } else {
                            ToastService.showError("No pubkey found", "Run \"nak key default\" in a terminal first.");
                        }
                    } else {
                        ToastService.showError("Could not derive pubkey", "Is nak installed and on PATH?");
                    }
                }, 0, 15000, root);
            }
        }

        DankButton {
            text: "Generate new key (copy)"
            onClicked: {
                Proc.runCommand("nostr.newkey", ["nak", "key", "generate"], (stdout, exitCode) => {
                    if (exitCode === 0) {
                        var key = String(stdout || "").trim();
                        if (key.length > 0) {
                            Quickshell.execDetached(["dms", "cl", "copy", key]);
                            ToastService.showInfo("New nsec copied", "Paste it into the key field above. It was NOT saved automatically.");
                        }
                    } else {
                        ToastService.showError("Key generation failed", "Is nak installed and on PATH?");
                    }
                }, 0, 15000, root);
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Tips: \"nak key default\" shows your machine key, \"nak key public <nsec>\" prints your hex pubkey, and njump.me can view your profile."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }
}