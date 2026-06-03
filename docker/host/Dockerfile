# =============================================================================
# Feishin "audio host" image
# -----------------------------------------------------------------------------
# Runs the *real* Feishin desktop (Electron) app HEADLESSLY on a server so that
# audio decodes and plays on the SERVER's hardware via mpv -> ALSA/PipeWire,
# instead of in a client browser.
#
#   * Electron app runs against a virtual X display (Xvfb).
#   * mpv is the audio engine (Settings -> Playback -> Audio player = MPV).
#     The "Audio device" dropdown then lists THIS machine's output devices.
#   * x11vnc + noVNC expose the UI in a browser for first-run configuration
#     (login, pick audio device, enable Remote Control) and occasional browsing.
#   * Feishin's built-in Remote Control server (default :4333) is what the
#     Stream Deck plugin and the lightweight web remote talk to.
#
# Build context = repo root:
#   docker build -f docker/host/Dockerfile -t feishin-host:latest .
# =============================================================================

# --- Builder stage: compile the Electron app (main + preload + renderer + remote)
FROM node:22-bookworm AS builder
WORKDIR /app

# Toolchain for any optional native addons (ws accelerators, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 build-essential ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Cache deps first
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && corepack prepare pnpm@10 --activate
# ELECTRON download is needed by postinstall (electron-builder install-app-deps)
RUN pnpm install --frozen-lockfile

# Build the electron bundles (out/main, out/preload, out/renderer) + remote (out/remote)
COPY . .
RUN pnpm run build

# --- Runtime stage
FROM debian:bookworm-slim AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    # Electron in a container: no setuid sandbox, no OS keyring
    ELECTRON_DISABLE_SANDBOX=1 \
    # Where Feishin persists settings/login (mount a volume here)
    FEISHIN_USER_DATA=/config \
    # Virtual display size (WIDTHxHEIGHTxDEPTH). Override in docker-compose.yaml.
    SCREEN_RESOLUTION=1920x1200x24

RUN apt-get update && apt-get install -y --no-install-recommends \
        # --- audio engine
        mpv \
        # --- headless display + remote viewing
        xvfb x11vnc openbox novnc websockify \
        # --- session bus (MPRIS / desktop integration; keeps Electron quiet)
        dbus dbus-x11 \
        # --- Electron 41 runtime libraries
        libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libgbm1 \
        libgtk-3-0 libasound2 libxcomposite1 libxdamage1 libxrandr2 \
        libxkbcommon0 libpango-1.0-0 libcairo2 libxshmfence1 libx11-xcb1 \
        libxcb-dri3-0 libxss1 libsecret-1-0 libnotify4 \
        # --- misc
        ca-certificates fonts-liberation tini supervisor \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# non-root user that can reach /dev/snd. The feishin user MUST be a real member
# of the "audio" group in /etc/group: supervisord drops privileges via
# initgroups(), which only grants groups the user is listed in — the compose
# `group_add` alone is NOT enough for the supervised process (it only affects
# docker-exec'd shells). Without this, mpv fails with "Playback open error: No
# such device". Debian's audio group is gid 29 (matches most hosts' /dev/snd).
RUN (getent group audio || groupadd -g 29 audio) \
    && useradd -m -u 1000 feishin \
    && usermod -aG audio feishin \
    && mkdir -p /config && chown feishin:feishin /config

# Copy the built app + the electron runtime (node_modules holds the electron
# binary). Ownership is set during COPY (--chown) — a recursive `chown -R` over
# the Electron node_modules is pathologically slow and duplicates the layer.
COPY --from=builder --chown=feishin:feishin /app/out           ./out
COPY --from=builder --chown=feishin:feishin /app/node_modules  ./node_modules
COPY --from=builder --chown=feishin:feishin /app/package.json  ./package.json
COPY --from=builder --chown=feishin:feishin /app/resources     ./resources
COPY --from=builder --chown=feishin:feishin /app/assets        ./assets

# Process supervision + launch scripts
COPY docker/host/supervisord.conf /etc/supervisor/conf.d/feishin.conf
COPY --chmod=0755 docker/host/launch-feishin.sh /usr/local/bin/launch-feishin.sh

# 4333 = Feishin Remote Control (Stream Deck + web remote)
# 6080 = noVNC (browser UI for setup / occasional browsing)
EXPOSE 4333 6080

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/feishin.conf"]
