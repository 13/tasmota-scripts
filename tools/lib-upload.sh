#!/usr/bin/env bash
# Shared Tasmota web-upload helper: prime /ufsd, POST /ufsu, verify via
# readback. Sourced by deploy.sh and tools/rollback.sh (not meant to be run
# directly).
#
# upload_one <ip> <local-path> <remote-name>
#   local-path's basename must equal remote-name (curl -F infers the upload
#   filename from it). Prints "  upload/verified/FAILED ..." lines and
#   returns non-zero on any failure, without exiting the caller (callers run
#   under `set -e` and are expected to check the return value themselves,
#   e.g. via `|| return 1`).
upload_one() {
  local ip=$1 local_path=$2 remote_name=$3
  echo "  upload $remote_name"
  # Tasmota only stores an /ufsu upload if the /ufsd page was requested
  # first (that sets Web.upload_file_type, and every upload resets it), so
  # prime it before each file. A bare POST is answered with HTTP 200 even
  # when nothing was written, so read the file back and compare bytes.
  curl -sf --connect-timeout 5 --max-time 30 -o /dev/null \
    "http://$ip/ufsd${TASMOTA_AUTH:+?$TASMOTA_AUTH}" \
    || { echo "  FAILED priming upload of $remote_name on $ip (device not restarted)"; return 1; }
  curl -sf --connect-timeout 5 --max-time 60 -F "ufsu=@$local_path" \
    "http://$ip/ufsu${TASMOTA_AUTH:+?$TASMOTA_AUTH}" >/dev/null \
    || { echo "  FAILED uploading $remote_name to $ip (device not restarted)"; return 1; }
  if ! curl -sf --connect-timeout 5 --max-time 30 \
      "http://$ip/ufsd?download=/$remote_name${TASMOTA_AUTH:+&$TASMOTA_AUTH}" \
      | cmp -s - "$local_path"; then
    echo "  FAILED: $remote_name on $ip does not match after upload (device not restarted)"
    return 1
  fi
  echo "  verified $remote_name"
}
