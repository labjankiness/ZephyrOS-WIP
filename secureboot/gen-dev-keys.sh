#!/usr/bin/env sh
#
# gen-dev-keys.sh - Generate development-time Secure Boot / MOK keys
#
# This script creates self-signed keys for **development only**. The private
# keys MUST NOT be committed to version control or shipped in public ISOs.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
KEY_DIR="$SCRIPT_DIR/keys"

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
    require_cmd openssl

    mkdir -p "$KEY_DIR"

    MOK_KEY="$KEY_DIR/MOK.key"
    MOK_CRT="$KEY_DIR/MOK.crt"

    if [ -f "$MOK_KEY" ] || [ -f "$MOK_CRT" ]; then
        log "Development MOK key material already exists under $KEY_DIR"
        log "Refusing to overwrite existing keys."
        exit 0
    fi

    log "Generating development MOK keypair under $KEY_DIR ..."

    # 2048-bit RSA key is sufficient for development use.
    openssl req -new -x509 -newkey rsa:2048 \
        -keyout "$MOK_KEY" \
        -out "$MOK_CRT" \
        -nodes \
        -days 3650 \
        -subj "/CN=ZephyrOS Development MOK/"

    log "Generated:"
    log "  Private key: $MOK_KEY"
    log "  Certificate: $MOK_CRT"
    log
    log "Next steps (high level):"
    log "  - Use this keypair to sign the kernel (and any custom modules)."
    log "  - Enroll the MOK certificate in the VM firmware via enroll-mok.sh."
}

main "$@"

