# Nostr plugin for DankMaterialShell

A [DankMaterialShell](https://danklinux.com/) plugin by [RogueHashrate] that turns your
shell into a nostr client: publish notes straight from the launcher, and get desktop
notifications whenever people reply, react, or zap your posts. Replies and reactions
can be sent right from the widget popout.

- **Daemon** — streams replies (`kind 1` **and** `kind 1111` long-form comments),
  reactions (`kind 7`) and zap receipts (`kind 9735`) tagged with your pubkey from your
  configured relays.
- **Widget** — a nostr-logo pill in your bar with an unread badge. Click it to open a
   popout with the latest activity; reply, react, or click an entry to open it on
   [njump.me](https://njump.me/) (configurable in settings).
- **Launcher** — type `n <your text>` in the launcher and press Enter to publish a note.
- **Settings** — nsec key, relays, event types to notify about, toasts.

> Backend: this plugin signs keys and streams relays with [nak](https://github.com/fiatjaf/nak),
> a command line nostr tool. **nak must be installed** before the plugin can start.

## Features

- **Color-coded notifications** — replies/mentions, reactions and zaps each get their
  own accent color, PFP avatars (falling back to a tinted initial circle), and a colored
  reaction badge on the avatar.
- **Color emoji** — emoji inside notifications render in full color (Noto Color Emoji)
  while normal text stays in the theme font.
- **Reply to comments** — each card has reply and reaction buttons. Replies target the
  comment itself (single `e`-tag), and mirror the thread's kind: `kind 1111` for a
  comment thread, `kind 1` otherwise.
- **Reaction picker** — a quick row of 12 emoji to pick from, published as a `kind 7`
  reaction to the exact comment.
- **Stable rolling list** — the popout keeps the last **2 hours** of activity, capped at
  **20 items**, newest first. Old items age out; nothing is reset or duplicated on
  restart and events are de-duplicated by id.

## Requirements

- [DankMaterialShell](https://danklinux.com/) **>= 1.5.0**
- [nak](https://github.com/fiatjaf/nak) on your `PATH`
- A nostr private key (`nsec1...`) — see *Configure* below

## Install

### 1. Install `nak`

The plugin uses `nak` for key handling, signing, and relay streaming, so install it
first. From the [nak repository](https://github.com/fiatjaf/nak) the quickest way is:

```sh
curl -sSL https://raw.githubusercontent.com/fiatjaf/nak/master/install.sh | sh
```

This installs it to `~/.local/bin` (make sure that's on your `PATH`). Alternatively
grab a prebuilt binary from the [releases page](https://github.com/fiatjaf/nak/releases)
or build from source with Go:

```sh
go install github.com/fiatjaf/nak@latest
```

Verify it works:

```sh
nak --version
```

> The plugin's startup check refuses to enable if `nak` is not found.

### 2. Install the plugin

Clone or copy this repo into the DMS plugins directory:

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r nostr-dms ~/.config/DankMaterialShell/plugins/nostr-dms
```

Or clone directly:

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
git clone https://github.com/roguehashrate/nostr-dms.git ~/.config/DankMaterialShell/plugins/nostr-dms
```

Then in DMS:

1. Open **Settings → Plugins** and enable **Nostr**.
2. Add the widget to your bar (drag **Nostr** onto a bar / enable it in the widget list).

The nostr-logo pill should appear in your bar; the watch indicator in the popout turns
red until the daemon connects.

## Configure

Open **Settings → Plugins → Nostr** and set:

| Setting | Purpose |
|---------|---------|
| `Private key (nsec)` | Your `nsec1...`. Leave empty to fall back to nak's machine default key (`nak key default`). |
| `Relays` | Relays to publish to and watch. Add write/read-friendly relays (e.g. `wss://relay.ditto.pub`). |
| `Notification link` | Base URL opened when clicking a notification (e.g. `https://njump.me/`, `https://primal.net/e/`). |
| `Watch history` | Historical look-back used when the daemon connects. |
| `Replies & mentions`, `Reactions`, `Zaps` | Toggles for which event types to notify about. |
| `Show toasts` | Show a desktop toast per notification. |

You can also paste your nsec directly from the popout: click the key icon in the popout
header. A **provisional key** note appears if you haven't set one yet.

## Usage

### Posting a note

1. Open the launcher.
2. Type `n hello nostr` and press Enter (or click the result).
3. A toast confirms delivery.

### Reading notifications

1. Click the nostr-logo pill to open the popout.
2. New activity shows as a numbered badge on the pill and a colored accent bar on the
   card. Each card shows the author's name/avatar, what they did, and when.
3. **Click any card** to open the thread on your configured nostr client (default: njump.me).
4. **Mark all read** (header) clears the unread badge.

### Replying

1. Hover a reply card and click the **reply icon**.
2. Type in the composer that appears and press Enter to send.
3. The reply is tagged to that comment and uses the same kind as the thread.

### Reacting

1. Hover a card and click the **reaction icon** (or the reply author's reaction badge).
2. Pick one of the 12 emoji in the row; it publishes the `kind 7` reaction immediately.
3. Publishing is tried against each of your relays in order, so a slow or rejecting
   relay doesn't stall the send.

## Troubleshooting

- **Plugin won't enable** — make sure `nak` is on `PATH` (`nak --version`), then
  re-enable. The startup check tells you exactly what's missing.
- **Nothing arrives** — verify the relays are reachable from your network, the daemon
  is connected (the header watch shows green; red = offline), and the pubkey you're
  watching matches the nsec you set:
  `nak key public`
- **Some relays reject publishes** — a few public relays refuse events from unknown
  keys. Replies and reactions still go through on relays that accept them.
- **Reply shows but no text** — large previews are one-line ellipsized; open the card
   on your configured client (default njump.me) to read the full thread.
- **Test the stream manually**:

  ```sh
  nak req --stream -k 1 -k 7 -k 9735 -k 1111 -p "$(nak key public)" -s -2h wss://relay.ditto.pub
  ```

- **Zap senders show the wallet service** — some wallets don't embed the sender's
  zap-request, so the wallet's pubkey is shown instead.

---

### Notes

- Author: **RogueHashrate** · License: see `LICENSE`.
- Deploy as a normal DMS plugin; versioned manifest lives in `plugin.json`.