# Feishin Audio Host (server-side playback)

Run the real Feishin desktop app **headless on a server** so music plays through
speakers attached to **that server** (e.g. the T630), not in a client browser.

## Why this exists

Feishin's standard Docker image (`docker-compose.yaml` in the repo root) is a
static **web build**: the browser decodes and plays the audio, and the "audio
device" list comes from the *client's* browser. It can never output to the
server's hardware.

The **MPV ("Audio player = MPV") engine** — and the device dropdown that comes
with it — only exists in the Electron desktop app. This image runs that desktop
app headlessly:

```
client browser ──(noVNC :6080)──┐
Stream Deck ─────(remote :4333)──┤
                                 ▼
                         Feishin (Electron, headless)
                                 │  mpv engine
                                 ▼
                         /dev/snd  →  server speakers
```

## Deploy on the T630

```bash
# on the T630, from the repo root:
docker compose -f docker/host/docker-compose.yaml up -d --build
```

The first build compiles the Electron app and takes a few minutes.

### Set the audio group GID

The container user needs access to `/dev/snd`. Check the host's audio group:

```bash
getent group audio      # e.g. "audio:x:29:"
```

Put that GID in `group_add:` in `docker-compose.yaml` (default `29`).

## First-run configuration (one time)

1. Open **http://&lt;t630-ip&gt;:6080/vnc.html** and click **Connect**. You'll see
   the Feishin UI on the virtual display.
2. **Log in** to your music server (Jellyfin / Navidrome / Subsonic).
3. **Settings → Playback → Audio player → MPV**.
4. **Settings → Playback → Audio device** → pick the server output (an
   `alsa/...` entry — this is the dropdown from the desktop app).
5. **Settings → (scroll to) Remote Control** → enable the server, set
   **port 4333** and a **username/password**. The Stream Deck plugin will use
   these.

Everything persists in the `feishin-host-config` volume, so subsequent restarts
need no display interaction.

## Verify audio

With speakers attached to the T630, queue a track from the noVNC UI and confirm
sound comes out of the server. Then control transport from the Stream Deck (see
`../../streamdeck` — Phase 2) or any device on the LAN.

## Audio backends

- **Bare ALSA (default):** `devices: /dev/snd`. Simplest for a headless box; no
  sound server required. mpv writes straight to the card.
- **PipeWire / PulseAudio:** see the commented `OPTION` block in
  `docker-compose.yaml` to mount the host's audio socket instead.

## Troubleshooting

- **No `alsa/...` devices in the dropdown:** the container can't see the card.
  Confirm `/dev/snd` is mapped and the `group_add` GID matches `getent group
  audio` on the host.
- **UI never appears in noVNC:** check `docker logs feishin-host` for Xvfb /
  Electron errors; ensure `shm_size` is set.
- **Electron exits immediately:** almost always the sandbox — this image already
  passes `--no-sandbox`; don't remove it.
