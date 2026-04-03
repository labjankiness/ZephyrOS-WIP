#!/usr/bin/env sh
#
# build-iso.sh - Reproducible ZephyrOS ISO build using archiso
#
# This script is intended to be run on an Arch (or Arch-based) build host
# with the archiso package installed. It produces a UEFI-only ISO image
# using the custom profile under build/archiso/.

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

PROFILE_DIR="$SCRIPT_DIR/archiso"
WORK_DIR="$SCRIPT_DIR/work"
OUT_DIR="$SCRIPT_DIR/out"

ISO_NAME="zephyros"

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
    require_cmd mkarchiso
    require_cmd sh

    if [ ! -d "$PROFILE_DIR" ]; then
        abort "Profile directory not found: $PROFILE_DIR"
    fi

    mkdir -p "$WORK_DIR" "$OUT_DIR"

    # Build AUR packages into a local pacman repo so mkarchiso can install them.
    LOCALREPO_BUILDER="$SCRIPT_DIR/scripts/build-localrepo.sh"
    if [ -f "$LOCALREPO_BUILDER" ]; then
        log "Preparing local repo (AUR packages)..."
        if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
            su - "$SUDO_USER" -c "sh \"$LOCALREPO_BUILDER\""
        else
            sh "$LOCALREPO_BUILDER"
        fi
    else
        abort "Local repo builder not found: $LOCALREPO_BUILDER"
    fi

    # Allow caller to override output version, otherwise use date.
    VERSION=${ZEPHYROS_ISO_VERSION:-$(date +%Y.%m.%d)}
    export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}

    log "Building ZephyrOS ISO..."
    log "  Profile : $PROFILE_DIR"
    log "  Workdir : $WORK_DIR"
    log "  Outdir  : $OUT_DIR"
    log "  Version : $VERSION"

    mkarchiso \
        -v \
        -w "$WORK_DIR" \
        -o "$OUT_DIR" \
        "$PROFILE_DIR"

    log "Build completed. Generated ISOs:"
    ls -1 "$OUT_DIR" 2>/dev/null || true
}

main "$@"

