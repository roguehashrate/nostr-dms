import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "nostrlib.js" as Nostr

PluginComponent {
    id: root

    property bool setupOpen: false

    PluginGlobalVar {
        id: unreadVar
        varName: "unread"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: notifVar
        varName: "notifications"
        defaultValue: []
    }

    PluginGlobalVar {
        id: connectedVar
        varName: "connected"
        defaultValue: false
    }

    PluginGlobalVar {
        id: statusVar
        varName: "status"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: keyVar
        varName: "usingDefaultKey"
        defaultValue: false
    }

    readonly property int unread: {
        var v = unreadVar.value;
        return (typeof v === "number") ? v : 0;
    }
    readonly property var items: Array.isArray(notifVar.value) ? notifVar.value : []
    readonly property bool connected: connectedVar.value === true
    readonly property bool usingDefaultKey: keyVar.value === true
    readonly property string lastStatus: String(statusVar.value || "")

    readonly property string badgeText: unread > 99 ? "99+" : String(unread)
    readonly property string detailsLine: {
        var base = connected ? "Watching replies, reactions & zaps" : "Offline";
        if (items.length > 0) {
            var unreadPart = unread > 0 ? unread + " unread" : "all caught up";
            base = items.length + " event" + (items.length === 1 ? "" : "s") + " \u00b7 " + unreadPart;
        }
        if (usingDefaultKey) {
            base += " \u00b7 provisional key";
        }
        return base;
    }

    function kindIcon(kind) {
        return Nostr.eventKindIcon(kind);
    }
    function kindColor(kind) {
        if (kind === Nostr.KIND_ZAP_RECEIPT) {
            return Theme.warning;
        }
        if (kind === Nostr.KIND_REACTION) {
            return Theme.secondary;
        }
        return Theme.primary;
    }
    function reactionEmoji(kind, content) {
        if (kind !== Nostr.KIND_REACTION) {
            return "";
        }
        return Nostr.reactionGlyph(content);
    }
    function bodyLine(modelData) {
        var text = String(modelData.text || "");
        if (text.length > 0) {
            return Nostr.preview(text, 140);
        }
        return Nostr.preview(String(modelData.verb || ""), 140);
    }
    function kindLabel(modelData) {
        if (modelData.kind === Nostr.KIND_ZAP_RECEIPT) {
            return modelData.sats > 0 ? Nostr.formatSats(modelData.sats) + " SATS" : "ZAP";
        }
        if (modelData.kind === Nostr.KIND_REACTION) {
            return "REACTED";
        }
        return (modelData.verb || "REPLY").toUpperCase();
    }
    function authorName(modelData) {
        if (modelData.name && String(modelData.name).length > 0) {
            return String(modelData.name);
        }
        if (modelData.author && String(modelData.author).length > 0) {
            return String(modelData.author);
        }
        return Nostr.shortPubkey(modelData.pubkey || "");
    }

    function markAllRead() {
        unreadVar.set(0);
    }

    property var replyTarget: null
    property bool replyBusy: false
    property bool reactBusy: false

    function startReply(modelData) {
        if (root.usingDefaultKey) {
            ToastService.showWarning("Add your key first", "Set your nsec with the key button to reply from your own account.");
            return;
        }
        root.replyTarget = modelData;
        replyField.text = "";
        replyField.forceActiveFocus();
    }

    function cancelReply() {
        root.replyTarget = null;
        replyBusy = false;
        replyField.text = "";
    }

    function sendReply() {
        if (replyBusy || !root.replyTarget) {
            return;
        }
        var text = String(replyField.text || "").trim();
        if (text.length === 0) {
            ToastService.showWarning("Empty reply", "Type something first.");
            return;
        }
        var nsec = String(pluginData.nsec || "").trim();
        if (nsec.length === 0) {
            root.cancelReply();
            ToastService.showWarning("No key", "Add your nsec in the key setup first.");
            return;
        }
        var relays = Nostr.normalizeRelays(pluginData.relays || Nostr.DEFAULT_RELAYS);
        if (relays.length === 0) {
            ToastService.showWarning("No relays", "Configure at least one relay in plugin settings.");
            return;
        }
        var args = ["nak", "event", "publish", "--sec", nsec, "-k", "1", "-c", text, "-e", root.replyTarget.id];
        if (root.replyTarget.rootId && root.replyTarget.rootId !== root.replyTarget.id) {
            args.push("-e", root.replyTarget.rootId);
        }
        args.push("-p", root.replyTarget.replyToPubkey || root.replyTarget.pubkey);
        args = args.concat(relays);
        replyBusy = true;
        Proc.runCommand("nostr.reply", args, (stdout, exitCode) => {
            replyBusy = false;
            if (exitCode === 0) {
                ToastService.showInfo("Reply sent", "Published to " + relays.length + " relay(s).");
                root.cancelReply();
            } else {
                var err = String(stdout || "").trim().split("\n");
                ToastService.showWarning("Reply failed", err.length > 0 ? err[err.length - 1] : "unknown error");
            }
        }, 0, 25000, root);
    }

    function sendReaction(target) {
        if (!target || reactBusy) {
            return;
        }
        if (root.usingDefaultKey) {
            ToastService.showWarning("Add your key first", "Set your nsec with the key button to react from your own account.");
            return;
        }
        var nsec = String(pluginData.nsec || "").trim();
        if (nsec.length === 0) {
            ToastService.showWarning("No key", "Add your nsec in the key setup first.");
            return;
        }
        var relays = Nostr.normalizeRelays(pluginData.relays || Nostr.DEFAULT_RELAYS);
        if (relays.length === 0) {
            ToastService.showWarning("No relays", "Configure at least one relay in plugin settings.");
            return;
        }
        var args = ["nak", "event", "publish", "--sec", nsec, "-k", "7", "-c", "+", "-e", target.id];
        if (target.rootId && target.rootId !== target.id) {
            args.push("-e", target.rootId);
        }
        args.push("-p", target.replyToPubkey || target.pubkey);
        args = args.concat(relays);
        reactBusy = true;
        Proc.runCommand("nostr.react", args, (stdout, exitCode) => {
            reactBusy = false;
            if (exitCode === 0) {
                ToastService.showInfo("Reaction sent", "You liked " + Nostr.shortPubkey(target.replyToPubkey || target.pubkey) + "'s note.");
            } else {
                var err = String(stdout || "").trim().split("\n");
                ToastService.showWarning("Reaction failed", err.length > 0 ? err[err.length - 1] : "unknown error");
            }
        }, 0, 25000, root);
    }

    function saveKey(text) {
        var key = String(text || "").trim();
        if (key.length === 0) {
            ToastService.showWarning("Empty key", "Paste your nsec1... into the field first.");
            return;
        }
        if (pluginService) {
            pluginService.savePluginData(pluginId, "nsec", key);
        }
        setupOpen = false;
        Proc.runCommand("nostr.pubkey", ["nak", "key", "public", key], (stdout, exitCode) => {
            if (exitCode === 0) {
                var pk = String(stdout || "").trim();
                var shortKey = pk.length >= 16 ? pk.slice(0, 12) + "..." + pk.slice(-4) : pk;
                ToastService.showInfo("Key saved", "Now watching as " + shortKey);
            } else {
                ToastService.showInfo("Key saved", "Reconnecting to relays with your key...");
            }
        }, 0, 15000, root);
    }

    popoutWidth: 440
    popoutHeight: 600

    horizontalBarPill: Component {
        Row {
            id: pillRow
            spacing: Theme.spacingXS

            DankIcon {
                id: pillIcon
                name: "bolt"
                size: root.iconSize
                filled: true
                color: root.unread > 0 ? Theme.primary : Theme.widgetIconColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Rectangle {
                id: pillBadge
                visible: root.unread > 0
                height: Math.max(18, pillBadgeLabel.implicitHeight + 4)
                radius: height / 2
                width: Math.max(height, pillBadgeLabel.implicitWidth + 8)
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: pillBadgeLabel
                    anchors.centerIn: parent
                    text: root.badgeText
                    color: Theme.onPrimary
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                id: pillOfflineDot
                visible: !root.connected && root.unread === 0
                width: 8
                height: 8
                radius: 4
                color: Theme.warning
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Item {
            width: root.widgetThickness
            height: pillCol.implicitHeight + Theme.spacingL * 2

            Column {
                id: pillCol
                anchors.centerIn: parent
                spacing: Theme.spacingXXS

                DankIcon {
                    name: "bolt"
                    size: root.iconSize - 6
                    filled: true
                    color: root.unread > 0 ? Theme.primary : Theme.widgetIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    visible: root.unread > 0
                    height: 16
                    radius: 8
                    width: Math.max(16, verticalBadgeLabel.implicitWidth + 6)
                    color: Theme.primary
                    anchors.horizontalCenter: parent.horizontalCenter

                    StyledText {
                        id: verticalBadgeLabel
                        anchors.centerIn: parent
                        text: root.badgeText
                        color: Theme.onPrimary
                        font.pixelSize: Theme.fontSizeSmall - 2
                        font.weight: Font.Bold
                    }
                }
            }

            Rectangle {
                visible: !root.connected && root.unread === 0
                width: 7
                height: 7
                radius: 4
                color: Theme.warning
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.top: parent.top
                anchors.topMargin: 4
            }
        }
    }

    popoutContent: Component {
        Column {
            id: popoutRoot
            width: parent.width
            height: implicitHeight

            property var closePopout: null

            Item {
                id: header
                width: parent.width
                height: 44

                Row {
                    id: headerActions
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingS
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    Rectangle {
                        id: statusChip
                        visible: root.items.length === 0 && !root.setupOpen
                        height: 24
                        radius: 12
                        color: root.connected ? Theme.withAlpha(Theme.primary, 0.14) : Theme.withAlpha(Theme.warning, 0.14)
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            anchors.centerIn: parent
                            leftPadding: Theme.spacingS
                            rightPadding: Theme.spacingS
                            spacing: 5

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: root.connected ? Theme.primary : Theme.warning
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: root.connected ? "Live" : "Offline"
                                color: root.connected ? Theme.primary : Theme.warning
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    DankActionButton {
                        id: keyButton
                        iconName: "key"
                        iconColor: Theme.warning
                        tooltipText: root.setupOpen ? "Close key setup" : "Add your nsec"
                        buttonSize: 32
                        visible: root.usingDefaultKey
                        onClicked: root.setupOpen = !root.setupOpen
                    }

                    DankActionButton {
                        id: clearButton
                        iconName: "done_all"
                        iconColor: root.unread > 0 ? Theme.primary : Theme.surfaceText
                        tooltipText: "Mark all read"
                        buttonSize: 32
                        visible: root.unread > 0
                        onClicked: root.markAllRead()
                    }

                    Rectangle {
                        id: closeButton
                        width: 32
                        height: 32
                        radius: 16
                        color: closeArea.containsMouse ? Theme.errorHover : Theme.withAlpha(Theme.errorHover, 0)

                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: Theme.iconSize - 4
                            color: closeArea.containsMouse ? Theme.error : Theme.surfaceText
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (popoutRoot.closePopout) {
                                    popoutRoot.closePopout();
                                }
                            }
                        }
                    }
                }

                StyledText {
                    id: headerTitle
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.right: headerActions.left
                    anchors.rightMargin: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nostr"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: Theme.fontSizeLarge + 4
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.withAlpha(Theme.surfaceText, 0.08)
            }

            Item {
                id: bodyRoot
                width: parent.width
                implicitHeight: root.popoutHeight - Theme.spacingS * 2 - header.height - 1 - replyBar.height

                Column {
                    anchors.fill: parent
                    spacing: 0

                    Item {
                        id: setupPanel
                        width: parent.width
                        height: root.setupOpen ? 158 : 0
                        visible: height > 0
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            radius: Theme.cornerRadius
                            color: Theme.nestedSurface
                            border.color: Theme.withAlpha(Theme.primary, 0.3)
                            border.width: 1

                            Column {
                                id: panelCol
                                width: parent.width - Theme.spacingM * 2
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.top: parent.top
                                anchors.topMargin: Theme.spacingM
                                spacing: Theme.spacingS

                                StyledText {
                                    width: parent.width
                                    text: "Add your private key"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                }

                                StyledText {
                                    width: parent.width
                                    text: "Paste your nsec1... (or hex) secret key. It is stored only in DMS plugin settings."
                                    color: Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    wrapMode: Text.WordWrap
                                }

                                DankTextField {
                                    id: keyField
                                    width: parent.width
                                    placeholderText: "nsec1..."
                                    echoMode: keyField.passwordVisible ? TextInput.Normal : TextInput.Password
                                    showPasswordToggle: true
                                    passwordVisible: false
                                    Keys.onReturnPressed: {
                                        root.saveKey(keyField.text);
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankButton {
                                        text: "Save key"
                                        onClicked: root.saveKey(keyField.text)
                                    }

                                    DankButton {
                                        text: "Cancel"
                                        backgroundColor: "transparent"
                                        textColor: Theme.surfaceVariantText
                                        onClicked: root.setupOpen = false
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: bodyArea
                        width: parent.width
                        height: parent.height - setupPanel.height

                        ListView {
                            id: listView
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            anchors.topMargin: Theme.spacingS
                            anchors.bottomMargin: Theme.spacingS
                            clip: true
                            spacing: Theme.spacingXS
                            model: root.items
                            visible: root.items.length > 0
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: StyledRect {
                                id: card
                                width: listView.width
                                height: 72
                                radius: Theme.cornerRadius
                                color: {
                                    if (innerArea.pressed) {
                                        return Theme.surfacePressed;
                                    }
                                    if (innerArea.containsMouse) {
                                        return Theme.surfaceContainerHighest;
                                    }
                                    if (index < root.unread) {
                                        return Theme.withAlpha(root.kindColor(modelData.kind), 0.12);
                                    }
                                    return Theme.surfaceContainerHigh;
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.shortDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Row {
                                    id: cardRow
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingM

                                    Item {
                                        width: 40
                                        height: parent.height

                                        Rectangle {
                                            id: avatarFallback
                                            anchors.centerIn: parent
                                            width: 40
                                            height: 40
                                            radius: 20
                                            color: Theme.withAlpha(root.kindColor(modelData.kind), 0.16)
                                            visible: modelData.kind === Nostr.KIND_REACTION || String(modelData.pfpUrl || "").length === 0

                                            DankIcon {
                                                anchors.centerIn: parent
                                                name: root.kindIcon(modelData.kind)
                                                size: 18
                                                filled: true
                                                color: root.kindColor(modelData.kind)
                                                visible: modelData.kind !== Nostr.KIND_REACTION
                                            }

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: root.reactionEmoji(modelData.kind, modelData.content)
                                                font.pixelSize: Theme.fontSizeXLarge
                                                visible: modelData.kind === Nostr.KIND_REACTION
                                            }
                                        }

                                        DankCircularImage {
                                            anchors.centerIn: parent
                                            width: 40
                                            height: 40
                                            visible: modelData.kind !== Nostr.KIND_REACTION && String(modelData.pfpUrl || "").length > 0
                                            imageSource: modelData.pfpUrl || ""
                                            fallbackIcon: root.kindIcon(modelData.kind)
                                            border.color: Theme.withAlpha(root.kindColor(modelData.kind), 0.25)
                                            border.width: 1
                                        }

                                        Rectangle {
                                            visible: index < root.unread
                                            width: 10
                                            height: 10
                                            radius: 5
                                            color: Theme.primary
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                        }
                                    }

                                    Column {
                                        width: parent.width - cardRow.spacing - 40 - 64
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            width: parent.width
                                            text: root.authorName(modelData)
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                            font.weight: Font.Bold
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: root.bodyLine(modelData)
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    Column {
                                        width: 64
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter

                                        Row {
                                            visible: modelData.kind === 1
                                            anchors.right: parent.right
                                            spacing: 4

                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: replyArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : "transparent"

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "reply"
                                                    size: 14
                                                    color: Theme.primary
                                                }

                                                MouseArea {
                                                    id: replyArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.startReply(modelData)
                                                }
                                            }

                                            Rectangle {
                                                width: 24
                                                height: 24
                                                radius: 12
                                                color: reactArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.16) : "transparent"

                                                DankIcon {
                                                    anchors.centerIn: parent
                                                    name: "thumb_up"
                                                    size: 14
                                                    color: Theme.primary
                                                }

                                                MouseArea {
                                                    id: reactArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.sendReaction(modelData)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            anchors.right: parent.right
                                            height: 18
                                            radius: 9
                                            width: Math.max(18, kindLabelText.implicitWidth + 10)
                                            color: Theme.withAlpha(root.kindColor(modelData.kind), 0.14)

                                            StyledText {
                                                id: kindLabelText
                                                anchors.centerIn: parent
                                                text: root.kindLabel(modelData)
                                                color: root.kindColor(modelData.kind)
                                                font.pixelSize: Theme.fontSizeSmall - 2
                                                font.weight: Font.Medium
                                            }
                                        }

                                        StyledText {
                                            width: parent.width
                                            text: Nostr.timeAgo(modelData.createdAt)
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall - 2
                                            horizontalAlignment: Text.AlignRight
                                        }
                                    }
                                }

                                MouseArea {
                                    id: innerArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://njump.me/" + modelData.id)
                                }
                            }
                        }

                        Item {
                            id: emptyState
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingS
                            anchors.rightMargin: Theme.spacingS
                            visible: root.items.length === 0

                            Column {
                                width: parent.width - Theme.spacingXL * 2
                                anchors.centerIn: parent
                                spacing: Theme.spacingM

                                Rectangle {
                                    width: 72
                                    height: 72
                                    radius: 36
                                    color: root.connected ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.warning, 0.12)
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: root.connected ? "bolt" : "wifi_off"
                                        size: 32
                                        filled: true
                                        color: root.connected ? Theme.primary : Theme.warning
                                    }
                                }

                                StyledText {
                                    width: parent.width
                                    text: root.connected ? "Listening for replies, reactions and zaps" : "Not connected"
                                    color: Theme.surfaceText
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }

                                StyledText {
                                    width: parent.width
                                    text: {
                                        if (root.connected && root.usingDefaultKey) {
                                            return "You are on nak's provisional key. Tap the key button above and paste your nsec to claim your identity.";
                                        }
                                        if (root.connected) {
                                            return "Activity on your posts will appear here.";
                                        }
                                        return root.lastStatus.length > 0 ? root.lastStatus : "Check that nak is installed and your relays are reachable.";
                                    }
                                    color: root.usingDefaultKey ? Theme.warning : Theme.surfaceVariantText
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: replyBar
                width: parent.width
                height: root.replyTarget ? 92 : 0
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surfaceContainerHigh

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Theme.withAlpha(Theme.surfaceText, 0.08)
                    }
                }

                Column {
                    id: replyBarContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    anchors.topMargin: Theme.spacingS
                    spacing: Theme.spacingXS

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Replying to "
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        StyledText {
                            text: root.replyTarget ? root.authorName(root.replyTarget) : ""
                            color: Theme.primary
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            width: parent.width - 100
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankTextField {
                            id: replyField
                            width: parent.width - 160
                            placeholderText: "Reply... (Enter to send)"
                            Keys.onReturnPressed: root.sendReply()
                        }

                        DankButton {
                            width: 76
                            text: "Send"
                            enabled: !root.replyBusy
                            onClicked: root.sendReply()
                        }

                        DankButton {
                            width: 76
                            text: "Cancel"
                            backgroundColor: "transparent"
                            textColor: Theme.surfaceVariantText
                            enabled: !root.replyBusy
                            onClicked: root.cancelReply()
                        }
                    }
                }
            }
        }
    }
}