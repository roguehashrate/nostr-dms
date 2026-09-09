.pragma library

var DEFAULT_RELAYS = [
    "wss://relay.damus.io",
    "wss://nos.lol",
    "wss://relay.snort.social",
    "wss://relay.primal.net"
];

var KIND_REACTION = 7;
var KIND_ZAP_RECEIPT = 9735;

function tagValues(tags, name) {
    var out = [];
    if (!tags || !Array.isArray(tags)) {
        return out;
    }
    for (var i = 0; i < tags.length; i++) {
        var t = tags[i];
        if (t && Array.isArray(t) && t.length > 1 && t[0] === name) {
            out.push(t[1]);
        }
    }
    return out;
}

function tagValue(tags, name) {
    var values = tagValues(tags, name);
    return values.length > 0 ? values[0] : null;
}

var REACTION_SHORTCODES = {
    "+": "\uD83D\uDC4D",
    "-": "\uD83D\uDC4E",
    "+1": "\uD83D\uDC4D",
    ":+1:": "\uD83D\uDC4D",
    "-1": "\uD83D\uDC4E",
    "100": "\uD83D\uDCAF",
    ":100:": "\uD83D\uDCAF",
    ":thumbsup:": "\uD83D\uDC4D",
    ":thumbsup_all:": "\uD83D\uDC4D",
    ":heart:": "\u2764\uFE0F",
    ":heartpulse:": "\uD83D\uDC96",
    ":joy:": "\uD83D\uDE02",
    ":laughing:": "\uD83D\uDE02",
    ":boom:": "\uD83D\uDCA5",
    ":fire:": "\uD83D\uDD25",
    ":star:": "\u2B50",
    ":wave:": "\uD83D\uDC4B",
    ":clap:": "\uD83D\uDC4F",
    ":party:": "\uD83E\uDD73",
    ":partying_face:": "\uD83E\uDD73",
    ":tada:": "\uD83C\uDF89",
    ":unamused:": "\uD83D\uDE12",
    ":eyes:": "\uD83D\uDC40",
    ":rocket:": "\uD83D\uDE80"
};

function reactionGlyph(content) {
    var c = String(content || "").trim();
    if (c.length === 0) {
        return "\uD83D\uDC4D";
    }
    if (REACTION_SHORTCODES[c]) {
        return REACTION_SHORTCODES[c];
    }
    return c;
}

function parseProfile(event) {
    var profile = {
        name: "",
        about: "",
        picture: ""
    };
    if (!event) {
        return profile;
    }
    try {
        var data = JSON.parse(String(event.content || "{}"));
        if (data && typeof data === "object") {
            profile.name = String(data.display_name || data.name || "").trim();
            profile.about = String(data.about || "").trim();
            profile.picture = String(data.picture || "").trim();
        }
    } catch (e) {}
    if (profile.name.length === 0) {
        profile.name = tagValue(event.tags, "display_name") || tagValue(event.tags, "name") || "";
    }
    if (profile.picture.length === 0) {
        profile.picture = tagValue(event.tags, "picture") || "";
    }
    return profile;
}

function displayName(name, pubkey) {
    if (typeof name === "string" && name.trim().length > 0) {
        return name.trim();
    }
    return shortPubkey(pubkey);
}

function formatSats(n) {
    var num = parseInt(n, 10);
    if (isNaN(num)) {
        return "0";
    }
    return String(num).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function hasTag(tags, name) {
    return tagValues(tags, name).length > 0;
}

function preview(content, max) {
    content = String(content || "");
    var oneLine = content.replace(/[\n\r]+/g, " ").replace(/\s+/g, " ").trim();
    if (oneLine.length <= max) {
        return oneLine;
    }
    return oneLine.slice(0, max) + "...";
}

function shortPubkey(pubkey) {
    if (typeof pubkey !== "string" || pubkey.length < 8) {
        return "unknown";
    }
    return pubkey.slice(0, 4) + "..." + pubkey.slice(-4);
}

function timeAgo(epochSeconds) {
    var now = Math.floor(Date.now() / 1000);
    var delta = Math.max(0, now - (epochSeconds || 0));
    if (delta < 60) {
        return "now";
    }
    if (delta < 3600) {
        return Math.floor(delta / 60) + "m";
    }
    if (delta < 86400) {
        return Math.floor(delta / 3600) + "h";
    }
    if (delta < 86400 * 30) {
        return Math.floor(delta / 86400) + "d";
    }
    var d = new Date((epochSeconds || 0) * 1000);
    return d.toLocaleTimeString(Qt.locale(), "hh:mm");
}

function satsFromZapReceipt(event) {
    var amount = parseInt(tagValue(event.tags, "amount"), 10);
    if (isNaN(amount) || amount < 0) {
        amount = 0;
    }
    return Math.round(amount / 1000);
}

function zapSenderPubkey(event) {
    var p = tagValue(event.tags, "P");
    if (typeof p === "string" && p.length === 64) {
        return p;
    }
    var description = tagValue(event.tags, "description");
    if (description) {
        try {
            var zapRequest = JSON.parse(description);
            if (zapRequest && typeof zapRequest.pubkey === "string" && zapRequest.pubkey.length === 64) {
                return zapRequest.pubkey;
            }
        } catch (e) {}
    }
    return event.pubkey || "";
}

function normalizeRelay(url) {
    if (!url) {
        return "";
    }
    url = String(url).trim();
    if (url.length === 0) {
        return "";
    }
    if (url.indexOf("://") === -1) {
        url = "wss://" + url;
    }
    while (url.length > 0 && url.charAt(url.length - 1) === "/") {
        url = url.slice(0, -1);
    }
    return url;
}

function normalizeRelays(relays) {
    var raw = relays;
    if (typeof raw === "string") {
        raw = [raw];
    }
    var seen = {};
    var out = [];
    if (!raw || !Array.isArray(raw)) {
        return out;
    }
    for (var i = 0; i < raw.length; i++) {
        var entry = raw[i];
        var url = typeof entry === "object" && entry ? entry.relay : entry;
        var r = normalizeRelay(url);
        if (r && !seen[r]) {
            seen[r] = true;
            out.push(r);
        }
    }
    return out;
}

function eventKindIcon(kind) {
    if (kind === KIND_ZAP_RECEIPT) {
        return "bolt";
    }
    if (kind === KIND_REACTION) {
        return "favorite";
    }
    return "chat";
}