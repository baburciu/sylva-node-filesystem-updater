#!/usr/bin/env bash
set -eo pipefail

# Sync files from /sources/ (projected Secret volume, auto-refreshed by kubelet)
# into /host-dir/ (hostPath mount on the node's real filesystem).
#
# FILE_PERMISSIONS – passed from the DaemonSet env; defaults to 0600.
# SYNC_INTERVAL    – seconds between sync loops; defaults to 30.

FILE_PERMISSIONS="${FILE_PERMISSIONS:-0600}"
SYNC_INTERVAL="${SYNC_INTERVAL:-30}"

while true; do
  for src in /sources/*; do
    [ -f "$src" ] || continue
    dest="/host-dir/$(basename "$src")"
    if ! cmp -s "$src" "$dest" 2>/dev/null; then
      install -m "$FILE_PERMISSIONS" "$src" "$dest"
      echo "$(date -u +%FT%TZ) [node-filesystem-updater] updated $dest (permissions $FILE_PERMISSIONS)"
    fi
  done
  sleep "$SYNC_INTERVAL"
done
