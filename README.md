# Nostr plugin for DankMaterialShell

A [DankMaterialShell](https://danklinux.com/) plugin that lets you publish nostr notes
straight from the launcher and shows desktop notifications when people reply, react,
or zap your posts.

- **Daemon**: streams relevant events (`kind 1` replies / mentions, `kind 7` reactions,
  `kind 9735` zap receipts) from your configured relays in the background.
- **Widget**: a bar pill with an unread badge. Click it to open a popout with the
  latest notifications. Clicking an entry opens the note on [njump.me](https://njump.me).
- **Launcher**: type `n <your text>` in the launcher and press Enter to publish.
- **Settings**: key, relays, history depth, which event types to notify about, toasts.

> Backend: this plugin uses the [nak](https://github.com/fiatjaf/nak) command line
> tool for keys, signing and relay streaming. It must be installed (see below).

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
| `Relays` | Relays to publish to and watch. Defaults: damus, nos.lol, snort.social, primal. |
| `Watch history` | Days of past activity loaded on start (1–30). |
| `Replies & mentions`, `Reactions`, `Zaps`, `Show toasts` | Toggles for what to notify about. |
| `Launcher trigger` | Prefix that starts a post (default `n`). |

Use the **Account helpers** buttons to copy your hex pubkey or generate a brand new key.

## Usage

- **Post**: open the launcher, type `n hello nostr`, click the result (or press Enter).
  A toast confirms delivery.
- **Notifications**: activity shows as an unread badge on the bolt pill. Open the popout
  to read the list; **Mark all read** clears the badge. Click an entry to view the
  thread on njump.me.
- The popout keeps the last 60 events even after a reload, and the unread count is
  restored the next session.

## Troubleshooting

- **Plugin won't enable**: make sure `nak` is on `PATH`, then re-enable. The startup
  check explains what's wrong.
- **Nothing arrives**: verify relays are reachable from your network, the daemon is
  running (the watch shows a red dot when disconnected), and your pubkey matches the
  nsec you set.
- **Test the stream manually**:

  ```sh
  nak key public   # your pubkey
  nak req --stream -k 1 -k 7 -k 9735 -p $(nak key public) -s -1d wss://relay.damus.io
  ```

- **Zap senders show the wallet service**: some wallets don't embed the sender's
  zap-request. When the `description` tag is present a different pubkey is shown.