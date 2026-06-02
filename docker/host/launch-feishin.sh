#!/usr/bin/env bash
# Launch the Feishin Electron app against the virtual display, with mpv audio.
# Run by supervisord after Xvfb is up.
set -euo pipefail

export DISPLAY="${DISPLAY:-:99}"
USER_DATA="${FEISHIN_USER_DATA:-/config}"

# Wait for Xvfb to accept connections
for i in $(seq 1 30); do
    if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

# Electron flags:
#   --no-sandbox          : required inside an unprivileged container
#   --user-data-dir       : persist login / settings / chosen audio device on the /config volume
#   --password-store=basic: no OS keyring in a container (safeStorage falls back gracefully)
#   --ozone-platform=x11  : force X11 backend on the virtual display
#
# dbus-run-session gives Electron its own private session bus (owned by this
# user) so the MPRIS / desktop integration connects cleanly instead of throwing
# EPIPE against a bus it has no permission to reach.
exec dbus-run-session -- /app/node_modules/.bin/electron /app \
    --no-sandbox \
    --password-store=basic \
    --ozone-platform=x11 \
    --user-data-dir="$USER_DATA"
