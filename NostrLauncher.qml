import QtQuick
import Quickshell.Io
import qs.Services
import "nostrlib3.js" as Nostr

Item {
    id: root

    property var pluginService: null
    property string trigger: "n"

    signal itemsChanged()

    readonly property string pluginId: "nostrDms"
    property string nsec: ""
    property var relays: []

    Component.onCompleted: {
        loadSettings();
    }

    function loadSettings() {
        if (!pluginService) {
            return;
        }
        trigger = pluginService.loadPluginData(pluginId, "trigger", "n") || "n";
        nsec = String(pluginService.loadPluginData(pluginId, "nsec", "") || "").trim();
        var raw = pluginService.loadPluginData(pluginId, "relays", null);
        relays = Nostr.normalizeRelays(raw || Nostr.DEFAULT_RELAYS);
    }

    function getItems(query) {
        var q = (query || "").trim();
        var categories = ["Nostr"];
        if (q.length === 0) {
            return [{
                name: "Write a nostr post",
                icon: "material:edit_note",
                comment: "Type your text after the trigger (e.g. " + trigger + " hello nostr) and press Enter to publish. Replies, reactions and zaps to your posts will show as notifications.",
                action: "post:",
                categories: categories
            }];
        }
        return [{
            name: "Publish \u201c" + Nostr.preview(q, 70) + "\u201d",
            icon: "material:send",
            comment: "nostr note \u00b7 " + relays.length + " relay" + (relays.length === 1 ? "" : "s") + (nsec.length > 0 ? "" : " \u00b7 using nak default key"),
            action: "post:" + q,
            categories: categories
        }];
    }

    function executeItem(item) {
        if (!item || !item.action) {
            return;
        }
        var parts = String(item.action).split(":");
        var type = parts[0];
        var data = parts.slice(1).join(":");
        if (type !== "post") {
            return;
        }
        var content = (data || "").trim();
        if (content.length === 0) {
            ToastService.showInfo("Nothing to publish", "Type your note text first.");
            return;
        }
        if (nsec.length === 0) {
            ToastService.showWarning("No key configured", "Set your nsec in plugin settings. Publishing with nak's default key.");
        }
        publish(content);
    }

    function publish(content) {
        var args = ["nak", "event"];
        if (nsec.length > 0) {
            args.push("--sec", nsec);
        }
        for (var i = 0; i < relays.length; i++) {
            args.push(relays[i]);
        }

        var proc = publishProcessComponent.createObject(root, {
            command: args,
            noteContent: content,
            relayCount: relays.length
        });
        proc.running = true;
    }

    Component {
        id: publishProcessComponent
        Process {
            property string noteContent: ""
            property int relayCount: 0
            property string stderrText: ""
            property string eventId: ""
            id: publishProcess
            stdinEnabled: true
            running: false
            stdout: SplitParser {
                onRead: line => {
                    var evt;
                    try {
                        evt = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (evt && evt.id) {
                        publishProcess.eventId = evt.id;
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    publishProcess.stderrText = text || "";
                }
            }
            onStarted: {
                publishProcess.write(JSON.stringify({ content: publishProcess.noteContent }) + "\n");
            }
            onExited: exitCode => {
                var failed = (String(publishProcess.stderrText).match(/failed:/g) || []).length;
                if (exitCode === 0) {
                    if (failed > 0) {
                        ToastService.showWarning("Note partially published", failed + " of " + publishProcess.relayCount + " relay(s) rejected it.");
                    } else {
                        var id = publishProcess.eventId.length > 0 ? " \u00b7 " + publishProcess.eventId.slice(0, 8) + "..." : "";
                        ToastService.showInfo("Note published", "Sent to " + publishProcess.relayCount + " relay(s)" + id + ".");
                    }
                } else {
                    var firstLines = String(publishProcess.stderrText).trim().split("\n").slice(0, 3).join("\n");
                    ToastService.showError("Failed to publish", firstLines || ("nak exited with " + exitCode));
                }
                Qt.callLater(() => publishProcess.destroy());
            }
        }
    }

    onTriggerChanged: {
        if (pluginService && trigger.length > 0) {
            pluginService.savePluginData(pluginId, "trigger", trigger);
        }
    }
}