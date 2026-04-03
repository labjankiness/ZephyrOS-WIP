#!/usr/bin/env sh
#
# enroll-mok.sh - Walkthrough for enrolling the ZephyrOS development MOK
#
# This script is intended to be run **inside the VM guest**. It:
#   - Locates the development MOK certificate
#   - Uses mokutil to schedule enrollment
#   - Explains the reboot flow to the user

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KEY_DIR_DEFAULT="$SCRIPT_DIR/keys"

log() {
    printf '%s\n' "$*" >&2
}

abort() {
    log "ERROR: $*"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || abort "Required command '$1' not found. Install it and retry."
}

main() {
    require_cmd mokutil

    KEY_DIR=${ZEPHYROS_MOK_KEY_DIR:-"$KEY_DIR_DEFAULT"}
    MOK_CRT="$KEY_DIR/MOK.crt"

    if [ ! -f "$MOK_CRT" ]; then
        abort "MOK certificate not found at $MOK_CRT.

If you built the ISO yourself, copy the public certificate into the VM, or
mount the host directory containing MOK.crt into the guest and re-run."
    fi

    log "Current Secure Boot state:"
    mokutil --sb-state || true
    log

    printf '%s\n' "You are about to enroll the ZephyrOS development MOK:"
    printf '  Certificate: %s\n' "$MOK_CRT"
    printf '%s\n' "You will be prompted to set a one-time password."
    printf '%s\n' "At next reboot, the firmware UI will ask you to confirm the MOK enrollment."
    printf '\n'

    printf '%s' "Continue and import this MOK? [y/N] "
    read ans || ans="n"
    case "$ans" in
        y|Y|yes|YES)
            ;;
        *)
            log "Aborted by user."
            exit 1
            ;;
    esac

    mokutil --import "$MOK_CRT"

    log
    log "MOK import scheduled. Now you must:"
    log "  1. Reboot the VM."
    log "  2. In the blue shim/MOK manager UI, choose 'Enroll MOK'."
    log "  3. Select 'View key' if you want to verify the certificate."
    log "  4. Confirm enrollment and enter the password you just set."
    log "  5. After the next boot, rerun 'mokutil --sb-state' to confirm."
}

main "$@"

