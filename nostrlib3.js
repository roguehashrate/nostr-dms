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
    ":-1:": "\uD83D\uDC4E",
    "100": "\uD83D\uDCAF",
    ":100:": "\uD83D\uDCAF",
    ":thumbsup:": "\uD83D\uDC4D",
    ":thumbsup_all:": "\uD83D\uDC4D",
    ":thumbsdown:": "\uD83D\uDC4E",
    ":ok_hand:": "\uD83D\uDC4C",
    ":wave:": "\uD83D\uDC4B",
    ":clap:": "\uD83D\uDC4F",
    ":raised_hands:": "\uD83D\uDE4C",
    ":pray:": "\uD83D\uDE4F",
    ":folded_hands:": "\uD83D\uDE4F",
    ":muscle:": "\uD83D\uDCAA",
    ":fist:": "\u270A",
    ":v:": "\u270C\uFE0F",
    ":victory:": "\u270C\uFE0F",
    ":metal:": "\uD83E\uDD18",
    ":call_me_hand:": "\uD83E\uDD19",
    ":hand:": "\u270B",
    ":open_hands:": "\uD83D\uDC50",
    ":heart:": "\u2764\uFE0F",
    ":red_heart:": "\u2764\uFE0F",
    ":purple_heart:": "\uD83D\uDC9C",
    ":pink_heart:": "\uD83D\uDC9C",
    ":blue_heart:": "\uD83D\uDC99",
    ":green_heart:": "\uD83D\uDC9A",
    ":yellow_heart:": "\uD83D\uDC9B",
    ":orange_heart:": "\uD83E\uDDE1",
    ":black_heart:": "\uD83D\uDDA4",
    ":white_heart:": "\uD83E\uDD0D",
    ":brown_heart:": "\uD83E\uDD0E",
    ":heart_exclamation:": "\u2763\uFE0F",
    ":broken_heart:": "\uD83D\uDC94",
    ":heartpulse:": "\uD83D\uDC96",
    ":heartbeat:": "\uD83D\uDC93",
    ":two_hearts:": "\uD83D\uDC95",
    ":sparkling_heart:": "\uD83D\uDC96",
    ":growing_heart:": "\uD83D\uDC97",
    ":revolving_hearts:": "\uD83D\uDC9E",
    ":cupid:": "\uD83D\uDC98",
    ":joy:": "\uD83D\uDE02",
    ":laughing:": "\uD83D\uDE06",
    ":grinning:": "\uD83D\uDE00",
    ":grin:": "\uD83D\uDE01",
    ":smile:": "\uD83D\uDE0A",
    ":smiley:": "\uD83D\uDE03",
    ":slightly_smiling_face:": "\uD83D\uDE42",
    ":wink:": "\uD83D\uDE09",
    ":blush:": "\uD83D\uDE0A",
    ":kissing_heart:": "\uD83D\uDE18",
    ":stuck_out_tongue:": "\uD83D\uDE1B",
    ":stuck_out_tongue_winking_eye:": "\uD83D\uDE1C",
    ":heart_eyes:": "\uD83D\uDE0D",
    ":star_struck:": "\uD83E\uDD29",
    ":thinking:": "\uD83E\uDD14",
    ":hushed:": "\uD83D\uDE2F",
    ":astonished:": "\uD83D\uDE32",
    ":sunglasses:": "\uD83D\uDE0E",
    ":nerd_face:": "\uD83E\uDD13",
    ":cowboy:": "\uD83E\uDD20",
    ":unamused:": "\uD83D\uDE12",
    ":disappointed:": "\uD83D\uDE1E",
    ":pensive:": "\uD83D\uDE14",
    ":confused:": "\uD83D\uDE15",
    ":sob:": "\uD83D\uDE2D",
    ":cry:": "\uD83D\uDE22",
    ":weary:": "\uD83D\uDE29",
    ":tired_face:": "\uD83D\uDE2B",
    ":angry:": "\uD83D\uDE20",
    ":rage:": "\uD83D\uDE21",
    ":flushed:": "\uD83D\uDE33",
    ":scream:": "\uD83D\uDE31",
    ":fearful:": "\uD83D\uDE28",
    ":cold_sweat:": "\uD83D\uDE30",
    ":sweat_smile:": "\uD83D\uDE05",
    ":skull:": "\uD83D\uDC80",
    ":ghost:": "\uD83D\uDC7B",
    ":alien:": "\uD83D\uDC7D",
    ":robot:": "\uD83E\uDD16",
    ":imp:": "\uD83D\uDC7F",
    ":poop:": "\uD83D\uDCA9",
    ":zzz:": "\uD83D\uDCAA",
    ":exploding_head:": "\uD83E\uDD2F",
    ":facepalm:": "\uD83E\uDD26",
    ":rolling_eyes:": "\uD83D\uDE44",
    ":shrug:": "\uD83E\uDD37",
    ":eyes:": "\uD83D\uDC40",
    ":fire:": "\uD83D\uDD25",
    ":boom:": "\uD83D\uDCA5",
    ":collision:": "\uD83D\uDCA5",
    ":rocket:": "\uD83D\uDE80",
    ":star:": "\u2B50",
    ":star2:": "\uD83C\uDF1F",
    ":sparkles:": "\u2728",
    ":tada:": "\uD83C\uDF89",
    ":confetti_ball:": "\uD83C\uDF8A",
    ":party:": "\uD83E\uDD73",
    ":partying_face:": "\uD83E\uDD73",
    ":clinking_glasses:": "\uD83E\uDD42",
    ":beers:": "\uD83C\uDF7B",
    ":trophy:": "\uD83C\uDFC6",
    ":medal:": "\uD83C\uDF96",
    ":gem:": "\uD83D\uDC8E",
    ":crown:": "\uD83D\uDC51",
    ":moneybag:": "\uD83D\uDCB0",
    ":money_with_wings:": "\uD83D\uDCB8",
    ":chart_with_upwards_trend:": "\uD83D\uDCC8",
    ":christmas_tree:": "\uD83C\uDF84",
    ":snowman:": "\u2603\uFE0F",
    ":snowflake:": "\u2744\uFE0F",
    ":sunny:": "\u2600\uFE0F",
    ":rainbow:": "\uD83C\uDF08",
    ":zap:": "\u26A1",
    ":thought_balloon:": "\uD83D\uDCAD",
    ":speech_balloon:": "\uD83D\uDCAC",
    ":dog:": "\uD83D\uDC36",
    ":cat:": "\uD83D\uDC31",
    ":fox_face:": "\uD83E\uDD8A",
    ":bear:": "\uD83D\uDC3B",
    ":panda_face:": "\uD83D\uDC3C",
    ":monkey_face:": "\uD83D\uDC35",
    ":frog:": "\uD83D\uDC38",
    ":pig:": "\uD83D\uDC37",
    ":bee:": "\uD83D\uDC1D",
    ":butterfly:": "\uD83E\uDD8B",
    ":unicorn:": "\uD83E\uDD84",
    ":taco:": "\uD83C\uDF2E",
    ":burrito:": "\uD83C\uDF2F",
    ":pizza:": "\uD83C\uDF55",
    ":hamburger:": "\uD83C\uDF54",
    ":fries:": "\uD83C\uDF5F",
    ":sushi:": "\uD83C\uDF63",
    ":cake:": "\uD83C\uDF82",
    ":birthday:": "\uD83C\uDF82",
    ":cookie:": "\uD83C\uDF6A",
    ":chocolate_bar:": "\uD83C\uDF6B",
    ":coffee:": "\u2615",
    ":tea:": "\uD83C\uDF75",
    ":beer:": "\uD83C\uDF7A",
    ":wine_glass:": "\uD83C\uDF77",
    ":doughnut:": "\uD83C\uDF69",
    ":ice_cream:": "\uD83C\uDF66",
    ":popcorn:": "\uD83C\uDF7F",
    ":soccer:": "\u26BD",
    ":basketball:": "\uD83C\uDFC0",
    ":football:": "\uD83C\uDFC8",
    ":tennis:": "\uD83C\uDFBE",
    ":baseball:": "\u26BE",
    ":game_die:": "\uD83C\uDFB2",
    ":video_game:": "\uD83C\uDFAE",
    ":bike:": "\uD83D\uDEB2",
    ":car:": "\uD83D\uDE97",
    ":taxi:": "\uD83D\uDE95",
    ":airplane:": "\u2708\uFE0F"
};

function emojiEnforceColor(s) {
    s = String(s || "");
    if (s.length === 0 || s.indexOf("\u200D") !== -1) {
        return s;
    }
    var first = s.charCodeAt(0);
    if (first >= 0xD83C && first <= 0xD83C) {
        var second = s.length > 1 ? s.charCodeAt(1) : 0;
        if (second >= 0xDDE6 && second <= 0xDDFF) {
            return s;
        }
    }
    if (s.charCodeAt(s.length - 1) === 0xFE0F) {
        return s;
    }
    return s + "\uFE0F";
}

function htmlEscape(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

function textHasEmoji(s) {
    s = String(s || "");
    for (var i = 0; i < s.length; i++) {
        if (s.charCodeAt(i) > 0x7e) {
            return true;
        }
    }
    return false;
}

function emojiHtml(input) {
    var s = String(input);
    var out = "";
    var plain = "";
    var emoji = "";
    var i = 0;
    while (i < s.length) {
        var c0 = s.charCodeAt(i);
        var isPlain = c0 <= 0x7e;
        if (isPlain) {
            if (emoji.length > 0) {
                out += '<font face="Noto Color Emoji">' + htmlEscape(emoji) + "</font>";
                emoji = "";
            }
            plain += s[i];
            i += 1;
        } else {
            if (plain.length > 0) {
                out += htmlEscape(plain);
                plain = "";
            }
            emoji += s[i];
            i += 1;
            if (c0 >= 0xd800 && c0 <= 0xdbff && i < s.length) {
                emoji += s[i];
                i += 1;
            }
        }
    }
    if (plain.length > 0) {
        out += htmlEscape(plain);
    }
    if (emoji.length > 0) {
        out += '<font face="Noto Color Emoji">' + htmlEscape(emoji) + "</font>";
    }
    return out;
}

function reactionGlyph(content) {
    var c = String(content || "").trim();
    if (c.length === 0) {
        return emojiEnforceColor("\uD83D\uDC4D");
    }
    if (REACTION_SHORTCODES[c]) {
        return emojiEnforceColor(REACTION_SHORTCODES[c]);
    }
    return emojiEnforceColor(c);
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