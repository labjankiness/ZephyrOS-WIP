#!/usr/bin/env sh
#
# sign-kernel.sh - Sign a Linux kernel image for Secure Boot
#
# Uses sbsign with the development MOK keypair created by gen-dev-keys.sh.

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

usage() {
    cat >&2 <<EOF
Usage: $0 /path/to/vmlinuz [output.efi]

Environment:
  ZEPHYROS_MOK_KEY_DIR  Directory containing MOK.key and MOK.crt
                        (default: $KEY_DIR_DEFAULT)
EOF
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || abort "Required command '$1' not found. Install it and retry."
}

main() {
    require_cmd sbsign

    if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
        usage
    fi

    KERNEL_IN=$1
    KERNEL_OUT=${2:-"${KERNEL_IN}.signed"}

    KEY_DIR=${ZEPHYROS_MOK_KEY_DIR:-"$KEY_DIR_DEFAULT"}
    MOK_KEY="$KEY_DIR/MOK.key"
    MOK_CRT="$KEY_DIR/MOK.crt"

    [ -f "$KERNEL_IN" ] || abort "Kernel image not found: $KERNEL_IN"
    [ -f "$MOK_KEY" ] || abort "Missing private key: $MOK_KEY"
    [ -f "$MOK_CRT" ] || abort "Missing certificate: $MOK_CRT"

    log "Signing kernel:"
    log "  Input : $KERNEL_IN"
    log "  Output: $KERNEL_OUT"
    log "  Key   : $MOK_KEY"
    log "  Cert  : $MOK_CRT"

    sbsign --key "$MOK_KEY" --cert "$MOK_CRT" \
        --output "$KERNEL_OUT" \
        "$KERNEL_IN"

    log "Signed kernel written to: $KERNEL_OUT"
}

main "$@"

