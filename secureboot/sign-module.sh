#!/usr/bin/env sh
#
# sign-module.sh - Sign a kernel module for Secure Boot
#
# For development, we reuse the same MOK keypair, but in production a
# dedicated module signing key is recommended.

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
Usage: $0 /path/to/module.ko

Environment:
  ZEPHYROS_MOK_KEY_DIR  Directory containing MOK.key and MOK.crt
                        (default: $KEY_DIR_DEFAULT)

Notes:
  - This script uses 'kmodsign' if available, otherwise falls back to
    the kernel's 'scripts/sign-file' helper when present.
EOF
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || return 1
}

main() {
    if [ "$#" -ne 1 ]; then
        usage
    fi

    MODULE=$1
    [ -f "$MODULE" ] || abort "Module not found: $MODULE"

    KEY_DIR=${ZEPHYROS_MOK_KEY_DIR:-"$KEY_DIR_DEFAULT"}
    MOK_KEY="$KEY_DIR/MOK.key"
    MOK_CRT="$KEY_DIR/MOK.crt"

    [ -f "$MOK_KEY" ] || abort "Missing private key: $MOK_KEY"
    [ -f "$MOK_CRT" ] || abort "Missing certificate: $MOK_CRT"

    HASH_ALG=sha256

    if require_cmd kmodsign; then
        log "Signing module with kmodsign..."
        kmodsign "$HASH_ALG" "$MOK_KEY" "$MOK_CRT" "$MODULE"
        log "Module signed: $MODULE"
        exit 0
    fi

    # Fallback: kernel's sign-file helper
    SIGN_FILE=""
    if [ -x "/usr/lib/modules/$(uname -r)/build/scripts/sign-file" ]; then
        SIGN_FILE="/usr/lib/modules/$(uname -r)/build/scripts/sign-file"
    elif [ -x "/usr/src/linux/scripts/sign-file" ]; then
        SIGN_FILE="/usr/src/linux/scripts/sign-file"
    fi

    if [ -z "$SIGN_FILE" ]; then
        abort "Neither 'kmodsign' nor 'sign-file' helper found."
    fi

    log "Signing module with sign-file helper..."
    "$SIGN_FILE" "$HASH_ALG" "$MOK_KEY" "$MOK_CRT" "$MODULE"
    log "Module signed: $MODULE"
}

main "$@"

