import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "nostrlib.js" as Nostr

PluginComponent {
    id: root

    property bool quitting: false
    property bool myConnected: false
    property string myPubkey: ""
    property var seenIds: []
    property int maxSeen: 4000
    property var notifications: []
    property int unreadCount: 0

    property string cfgNsec: ""
    property var cfgRelays: []
    property int cfgSinceDays: 7
    property bool cfgWatchReplies: true
    property bool cfgWatchReactions: true
    property bool cfgWatchZaps: true
    property bool cfgShowToasts: true
    property var profiles: ({})
    property var profileInFlight: ({})
    property int profileMaxActive: 3
    property int profileActive: 0
    property var profileQueue: []

    Component.onCompleted: {
        reloadConfig();
        loadHistory();
        derivePubkey();
    }

    Component.onDestruction: {
        quitting = true;
        if (keqProcess.running) {
            keqProcess.running = false;
        }
    }

    Connections {
        target: pluginService
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== pluginId) {
                return;
            }
            reloadConfig();
            if (keqProcess.running) {
                restartWatch();
            }
        }
    }

    Connections {
        target: PluginService
        function onGlobalVarChanged(changedPluginId, varName) {
            if (changedPluginId !== pluginId || varName !== "unread") {
                return;
            }
            unreadCount = PluginService.getGlobalVar(pluginId, "unread", 0) || 0;
            if (pluginService) {
                pluginService.savePluginState(pluginId, "unreadCount", unreadCount);
            }
        }
    }

    function reloadConfig() {
        cfgNsec = String(pluginData.nsec || "").trim();
        cfgRelays = Nostr.normalizeRelays(pluginData.relays || Nostr.DEFAULT_RELAYS);
        var days = parseInt(pluginData.sinceDays, 10);
        cfgSinceDays = isNaN(days) ? 7 : Math.max(1, Math.min(30, days));
        cfgWatchReplies = pluginData.watchReplies !== false;
        cfgWatchReactions = pluginData.watchReactions !== false;
        cfgWatchZaps = pluginData.watchZaps !== false;
        cfgShowToasts = pluginData.showToasts !== false;
        PluginService.setGlobalVar(pluginId, "usingDefaultKey", cfgNsec.length === 0);
        log.info("nostr cfg watch R", cfgWatchReplies, "X", cfgWatchReactions, "Z", cfgWatchZaps, "nsec", cfgNsec.length > 0, "relays", cfgRelays.length, "strict", JSON.stringify(Object.keys(pluginData || {})));
    }

    function loadHistory() {
        if (!pluginService) {
            return;
        }
        var saved = pluginService.loadPluginState(pluginId, "notifications", []);
        if (Array.isArray(saved)) {
            notifications = saved.slice(0, 60);
        }
        var savedUnread = pluginService.loadPluginState(pluginId, "unreadCount", 0);
        unreadCount = isNaN(savedUnread) ? 0 : savedUnread;
        publishState();
    }

    function derivePubkey() {
        var args;
        if (cfgNsec.length > 0) {
            args = ["nak", "key", "public", cfgNsec];
        } else {
            args = ["nak", "key", "public"];
        }
        Proc.runCommand("nostr.pubkey", args, (stdout, exitCode) => {
            if (quitting) return;
            if (exitCode === 0) {
                var pk = String(stdout || "").trim();
                if (pk.length === 64) {
                    startWatch(pk);
                } else {
                    setConnected(false, "nak key public returned: " + pk);
                }
            } else {
                setConnected(false, "Could not derive your pubkey. Set an nsec in plugin settings.");
            }
        }, 0, 15000, root);
    }

    function startWatch(pubkey) {
        if (quitting || keqProcess.running) {
            return;
        }
        myPubkey = pubkey;
        if (cfgRelays.length === 0) {
            setConnected(false, "No relays configured in plugin settings.");
            return;
        }
        var cmd = ["nak", "req", "--stream", "-k", "1", "-k", "7", "-k", "9735", "-p", myPubkey];
        var now = Math.floor(Date.now() / 1000);
        var since = now - cfgSinceDays * 86400;
        cmd.push("-s", String(since));
        for (var i = 0; i < cfgRelays.length; i++) {
            cmd.push(cfgRelays[i]);
        }
        var quoted = cmd.map(function (t) {
            return "'" + String(t).replace(/'/g, "'\\''") + "'";
        });
        keqProcess.command = ["bash", "-c", quoted.join(" ") + " < /dev/null"];
        keqProcess.running = true;
    }

    function restartWatch() {
        if (keqProcess.running) {
            keqProcess.running = false;
        }
        restartTimer.interval = 1500;
        restartTimer.start();
    }

    function onEventLine(line) {
        var evt;
        try {
            evt = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!evt || typeof evt !== "object" || !evt.id || !evt.kind) {
            return;
        }
        if (seenIds.indexOf(evt.id) !== -1) {
            return;
        }
        seenIds.push(evt.id);
        if (seenIds.length > maxSeen) {
            seenIds = seenIds.slice(seenIds.length - maxSeen);
        }
        if (evt.pubkey === myPubkey) {
            return;
        }
        log.info("nostr event kind=", evt.kind, "author=", Nostr.shortPubkey(evt.pubkey), "id=", String(evt.id).slice(0, 8));
        try {
            handleEvent(evt);
        } catch (e) {
            log.info("nostr HANDLE ERROR:", String(e && e.message ? e.message : e));
        }
    }

    function handleEvent(evt) {
        var entry = {
            id: evt.id,
            kind: evt.kind,
            pubkey: evt.pubkey,
            authorPubkey: evt.pubkey,
            createdAt: evt.created_at || 0,
            content: evt.content || "",
            verb: "",
            sats: 0,
            title: "",
            text: "",
            icon: "bolt",
            name: "",
            pfpUrl: "",
            replyToPubkey: "",
            rootId: ""
        };

        if (evt.kind === Nostr.KIND_ZAP_RECEIPT) {
            if (!cfgWatchZaps) {
                return;
            }
            var senderPk = Nostr.zapSenderPubkey(evt);
            var sats = Nostr.satsFromZapReceipt(evt);
            var zapComment = String(evt.content || "").trim();
            entry.authorPubkey = senderPk;
            entry.pubkey = senderPk;
            entry.verb = "zapped you";
            entry.sats = sats;
            entry.title = "Zap " + Nostr.formatSats(sats) + " sats";
            entry.icon = "bolt";
        } else if (evt.kind === Nostr.KIND_REACTION) {
            if (!cfgWatchReactions) {
                return;
            }
            var glyph = Nostr.reactionGlyph(evt.content);
            entry.verb = "reacted " + glyph;
            entry.title = "Reacted " + glyph;
            entry.icon = "favorite";
        } else if (evt.kind === 1) {
            if (!cfgWatchReplies) {
                return;
            }
            var eTags = Nostr.tagValues(evt.tags, "e");
            var pTags = Nostr.tagValues(evt.tags, "p");
            var isReply = eTags.length > 0;
            var isMention = pTags.indexOf(myPubkey) !== -1;
            entry.replyToPubkey = evt.pubkey;
            entry.rootId = eTags.length > 0 ? eTags[eTags.length - 1] : evt.id;
            entry.verb = isReply ? "replied" : isMention ? "mentioned you" : "sent you a note";
            entry.title = isReply ? "Reply to your post" : isMention ? "Mention" : "Note to you";
            entry.icon = "chat";
        } else {
            return;
        }

        enrichEntryFromCache(entry);

        var who = entry.name.length > 0 ? entry.name : Nostr.shortPubkey(entry.authorPubkey);
        if (entry.kind === Nostr.KIND_ZAP_RECEIPT) {
            entry.text = who + " zapped you \u26A1" + Nostr.formatSats(entry.sats) + " sats" + (zapComment.length > 0 ? ': "' + Nostr.preview(zapComment, 90) + '"' : "");
        } else if (entry.kind === Nostr.KIND_REACTION) {
            entry.text = who + " reacted " + Nostr.reactionGlyph(entry.content);
        } else {
            entry.text = who + ": " + Nostr.preview(evt.content, 140);
        }

        ensureProfile(entry.authorPubkey);

        notifications.unshift(entry);
        if (notifications.length > 60) {
            notifications = notifications.slice(0, 60);
        }
        unreadCount += 1;
        persistState();
        publishState();

        if (cfgShowToasts) {
            ToastService.showInfo(entry.title, entry.text);
        }
        log.info("nostr notification:", entry.title);
    }

    function enrichEntryFromCache(entry) {
        var p = profiles[entry.authorPubkey];
        if (p) {
            if (typeof p.name === "string" && p.name.length > 0) {
                entry.name = p.name;
            }
            if (typeof p.picture === "string" && p.picture.length > 0) {
                entry.pfpUrl = p.picture;
            }
        }
    }

    function ensureProfile(pk) {
        if (!pk || typeof pk !== "string" || pk.length !== 64 || pk === myPubkey) {
            return;
        }
        if (profiles[pk] !== undefined || profileInFlight[pk]) {
            return;
        }
        if (cfgRelays.length === 0) {
            profiles[pk] = null;
            return;
        }
        profileInFlight[pk] = true;
        profileQueue.push({ pk: pk, relayIdx: 0 });
        drainProfileQueue();
    }

    function drainProfileQueue() {
        while (profileActive < profileMaxActive && profileQueue.length > 0 && !quitting) {
            var job = profileQueue.shift();
            profileActive += 1;
            queryProfileRelay(job.pk, job.relayIdx);
        }
    }

    function queryProfileRelay(pk, relayIdx) {
        if (quitting) {
            return;
        }
        if (relayIdx >= cfgRelays.length || !cfgRelays[relayIdx]) {
            profileInFlight[pk] = false;
            if (profiles[pk] === undefined) {
                profiles[pk] = null;
            }
            profileActive -= 1;
            drainProfileQueue();
            return;
        }
        var relay = cfgRelays[relayIdx];
        log.info("nostr profile fetch", Nostr.shortPubkey(pk), relay);
        var inner = "nak req -k 0 -a " + pk + " " + relay + " 2>&1 < /dev/null";
        var args = ["bash", "-c", inner];
        Proc.runCommand("nostr.profile." + pk + "." + relayIdx, args, (stdout, exitCode) => {
            var out = String(stdout || "");
            if (exitCode === 0 || exitCode === 124) {
                var best = findProfileEvent(out, pk);
                if (best) {
                    profileInFlight[pk] = false;
                    profiles[pk] = Nostr.parseProfile(best);
                    log.info("nostr profile fetched for", Nostr.shortPubkey(pk));
                    updateProfiledEntries(pk);
                    profileActive -= 1;
                    drainProfileQueue();
                    return;
                }
            }
            queryProfileRelay(pk, relayIdx + 1);
        }, 0, 10000, root);
    }

    function findProfileEvent(output, pk) {
        var lines = output.split("\n");
        var best = null;
        var bestTs = 0;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];
            if (line.length === 0) {
                continue;
            }
            var e;
            try {
                e = JSON.parse(line);
            } catch (err) {
                continue;
            }
            if (e && e.kind === 0 && e.pubkey === pk) {
                var ts = parseInt(e.created_at, 10) || 0;
                if (ts >= bestTs) {
                    bestTs = ts;
                    best = e;
                }
            }
        }
        return best;
    }

    function updateProfiledEntries(pk) {
        var p = profiles[pk] || null;
        for (var i = 0; i < notifications.length; i++) {
            var entry = notifications[i];
            if (entry.authorPubkey === pk) {
                entry.name = p ? (p.name || "") : "";
                entry.pfpUrl = p ? (p.picture || "") : "";
            }
        }
        publishState();
    }

    function persistState() {
        if (!pluginService) {
            return;
        }
        pluginService.savePluginState(pluginId, "notifications", notifications);
        pluginService.savePluginState(pluginId, "unreadCount", unreadCount);
    }

    function publishState() {
        PluginService.setGlobalVar(pluginId, "notifications", notifications);
        PluginService.setGlobalVar(pluginId, "unread", unreadCount);
    }

    function setConnected(ok, message) {
        myConnected = ok;
        PluginService.setGlobalVar(pluginId, "connected", ok);
        if (!ok) {
            PluginService.setGlobalVar(pluginId, "status", String(message || "Nostr feed disconnected"));
        }
    }

    Timer {
        id: restartTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (!quitting && myPubkey.length === 64) {
                startWatch(myPubkey);
            }
        }
    }

    Process {
        id: keqProcess
        command: []
        running: false
        stderr: StdioCollector {
            id: procStderr
            onStreamFinished: {
                var err = String(text || "").trim().split("\n").filter(function (l) {
                    return l.length > 0 && l.indexOf("stopped the connection") === -1;
                });
                if (err.length > 0 && root.myConnected) {
                    PluginService.setGlobalVar(pluginId, "status", err[err.length - 1]);
                }
            }
        }
        stdout: SplitParser {
            onRead: line => root.onEventLine(line)
        }
        onStarted: {
            setConnected(true, "");
            log.info("nostr watch connected for", String(myPubkey).slice(0, 8));
        }
        onExited: (exitCode, exitStatus) => {
            setConnected(false, "Nostr watch stopped (exit " + exitCode + ")");
            if (!quitting) {
                restartTimer.interval = 5000;
                restartTimer.start();
            }
        }
    }
}