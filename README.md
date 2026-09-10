# Nostr plugin for DankMaterialShell

A [DankMaterialShell](https://danklinux.com/) plugin by [RogueHashrate] that lets you
publish nostr notes straight from the launcher and get desktop notifications whenever
people reply, react, or zap your posts.

- **Daemon**: streams replies (`kind 1` **and** `kind 1111`), reactions (`kind 7`) and
  zap receipts (`kind 9735`) tagged with your pubkey from your configured relays.
- **Widget**: a bolt pill with an unread badge. Click it to open a popout with the
  latest activity. Reply or react to comments right from the popout, or click an entry
  to open the thread on [njump.me](https://njump.me).
- **Launcher**: type `n <your text>` in the launcher and press Enter to publish.
- **Settings**: key, relays, event types to notify about, toasts.

> Backend: this plugin uses the [nak](https://github.com/fiatjaf/nak) command line
> tool for keys, signing and relay streaming. It must be installed (see below).

## Features

- **Color-coded notifications** — replies & mentions, reactions, and zaps each get
  their own accent color, PFP avatars (with a fallback tinted circle), and a colored
  reaction badge on the avatar.
- **Color emoji** — reactions and emoji inside notes render in full color
  (Noto Color Emoji) while text stays in the theme font.
- **Reply in the right kind** — replying to a `kind 1111` comment replies with
  `kind 1111`, otherwise `kind 1`. Replies target the comment (single `e`-tag), not
  your original post.
- **Reaction picker** — click the reaction icon (or the comment's button) to open a
  quick row of 12 emoji to react with, published as a `kind 7` tagged to that comment.
- **Stable list** — the notification list is a rolling window: it keeps activity from
  the last 2 hours, capped at 20 items, newest first. Old items age out; restarts
  don't reset or balloon the list, and duplicate events are de-duplicated by id.

## Install

### 1. Install `nak`

```sh
curl -sSL https://raw.githubusercontent.com/fiatjaf/nak/master/install.sh | sh
```

Verify: `nak version`. The plugin refuses to start if `nak` is missing.

### 2. Install the plugin

Copy this folder into the DMS plugins directory:

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r /home/roguehashrate/code/nostr-dms ~/.config/DankMaterialShell/plugins/nostr-dms
```

Then in DMS **Settings → Plugins**, enable **Nostr** and add the widget to your bar.

## Configure

Open the plugin settings and set:

| Setting | Purpose |
|---------|---------|
| `Private key (nsec)` | Your `nsec1...`. Leave empty to fall back to nak's machine default key (`nak key default`). |
| `Relays` | Relays to publish to and watch. |
| `Replies & mentions`, `Reactions`, `Zaps`, `Show toasts` | Toggles for what to notify about. |

Alternatively, tap the key button in the popout header to paste your nsec there.

## Usage

- **Post**: open the launcher, type `n hello nostr`, click the result (or press Enter).
  A toast confirms delivery.
- **Notifications**: activity appears as an unread badge on the bolt pill. Open the
  popout to read the list; **Mark all read** clears the badge. Click an entry to view
  the thread on njump.me.
- **Reply**: hover a comment card and click the reply icon, type, and press Enter.
- **React**: hover a comment card and click the reaction icon to open the emoji row,
  then pick one. Publishing is tried against each of your relays in order, so a slow
  or rejecting relay doesn't stall the send.

## Troubleshooting

- **Plugin won't enable**: make sure `nak` is on `PATH`, then re-enable. The startup
  check explains what's wrong.
- **Nothing arrives**: verify relays are reachable from your network, the daemon is
  running (the watch shows a red dot when disconnected), and your pubkey matches the
  nsec you set.
- **Some relays reject publishes**: a few public relays refuse to accept events from
  unknown keys; replies/reactions will still go through on relays that accept them.
- **Test the stream manually**:

  ```sh
  nak key public   # your pubkey
  nak req --stream -k 1 -k 7 -k 9735 -k 1111 -p $(nak key public) -s -2h wss://relay.ditto.pub
  ```

- **Zap senders show the wallet service**: some wallets don't embed the sender's
  zap-request. When the `description` tag is present a different pubkey is shown.