#!/usr/bin/env sh

#

# build-edition.sh — Build a ZephyrOS edition ISO

#

# Usage:

#   ./build-edition.sh scholar    # Build Scholar edition

#   ./build-edition.sh dev        # Build Dev edition

#   ./build-edition.sh soc        # Build SOC edition

#   ./build-edition.sh lite       # Build Lite edition

#   ./build-edition.sh core       # Build Core (base only, no AI model)

#

# How it works:

#   1. Reads editions/base/ for shared packages and configs

#   2. Reads editions/<name>/ for edition-specific overlays

#   3. Merges packages (base + edition), deduplicates

#   4. Copies the archiso profile and overlays edition airootfs files

#   5. Injects the edition config and first-boot service

#   6. Calls mkarchiso to produce the final ISO

#

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

EDITIONS_DIR="$ROOT_DIR/editions"

BASE_DIR="$EDITIONS_DIR/base"

ARCHISO_PROFILE="$SCRIPT_DIR/archiso"

abort() {

    printf 'ERROR: %s\n' "$*" >&2

    exit 1

}

log() {

    printf '[build-edition] %s\n' "$*" >&2

}

usage() {

    cat >&2 <<EOF

Usage: $0 <edition>

Available editions:

  core     — Base desktop, no AI model

  scholar  — Student edition (Phi-3 Mini)

  dev      — Developer edition (DeepSeek Coder V2 Lite)

  soc      — Security analyst edition (Llama 3.1 8B)

  lite     — Lightweight edition (SmolLM2 1.7B)

EOF

    exit 1

}

merge_packages() {

    BASE_PKGS="$1"

    EDITION_PKGS="$2"

    OUTPUT="$3"

    # Merge both package lists, strip comments and blank lines, deduplicate

    {

        [ -f "$BASE_PKGS" ] && cat "$BASE_PKGS"

        [ -f "$EDITION_PKGS" ] && cat "$EDITION_PKGS"

    } | grep -v '^\s*#' | grep -v '^\s*$' | sort -u > "$OUTPUT"

}

main() {

    if [ "$#" -lt 1 ]; then

        usage

    fi

    EDITION="$1"

    EDITION_DIR="$EDITIONS_DIR/$EDITION"

    # Core edition uses base only

    if [ "$EDITION" = "core" ]; then

        EDITION_DIR="$BASE_DIR"

    fi

    if [ ! -d "$EDITION_DIR" ] && [ "$EDITION" != "core" ]; then

        abort "Unknown edition: $EDITION (no directory at $EDITION_DIR)"

    fi

    # Load edition config

    EDITION_CONF="$EDITION_DIR/edition.conf"

    if [ ! -f "$EDITION_CONF" ]; then

        abort "No edition.conf found in $EDITION_DIR"

    fi

    # shellcheck source=/dev/null

    . "$EDITION_CONF"

    log "Building ZephyrOS $EDITION_LABEL"

    log "  Edition  : $EDITION"

    log "  Model    : ${OLLAMA_MODEL:-none}"

    # --- Prepare a temporary build profile ---

    WORK_DIR="$SCRIPT_DIR/work-$EDITION"

    OUT_DIR="$SCRIPT_DIR/out"

    PROFILE_TMP="$WORK_DIR/profile"

    rm -rf "$WORK_DIR"

    mkdir -p "$WORK_DIR" "$OUT_DIR"

    # Copy the base archiso profile

    cp -a "$ARCHISO_PROFILE" "$PROFILE_TMP"

    # Merge packages

    log "Merging package lists..."

    EDITION_PKGS="$EDITION_DIR/packages.x86_64"

    merge_packages "$BASE_DIR/packages.x86_64" "$EDITION_PKGS" "$PROFILE_TMP/packages.x86_64"

    PKG_COUNT=$(wc -l < "$PROFILE_TMP/packages.x86_64")

    log "  Total packages: $PKG_COUNT"

    # --- Overlay edition airootfs ---

    if [ -d "$EDITION_DIR/airootfs" ]; then

        log "Applying edition airootfs overlay..."

        cp -a "$EDITION_DIR/airootfs/." "$PROFILE_TMP/airootfs/"

    fi

    # --- Inject first-boot service and config ---

    AIROOTFS="$PROFILE_TMP/airootfs"

    mkdir -p "$AIROOTFS/usr/local/bin"

    mkdir -p "$AIROOTFS/usr/lib/systemd/system/multi-user.target.wants"

    mkdir -p "$AIROOTFS/etc"

    cp "$BASE_DIR/zephyros-firstboot.sh" "$AIROOTFS/usr/local/bin/zephyros-firstboot.sh"

    cp "$BASE_DIR/zephyros-firstboot.service" "$AIROOTFS/usr/lib/systemd/system/zephyros-firstboot.service"

    # Symlink to enable the service

    ln -sf ../zephyros-firstboot.service \
        "$AIROOTFS/usr/lib/systemd/system/multi-user.target.wants/zephyros-firstboot.service"

    # Write edition config into the ISO

    cp "$EDITION_CONF" "$AIROOTFS/etc/zephyros-edition.conf"

    # --- Update profiledef.sh for this edition ---

    sed -i \
        -e "s|^iso_name=.*|iso_name=\"${ISO_NAME}\"|" \
        -e "s|^iso_application=.*|iso_application=\"${EDITION_LABEL} Live ISO\"|" \
        -e "s|^iso_label=.*|iso_label=\"${ISO_NAME^^}_\$(date +%Y%m)\"|" \
        "$PROFILE_TMP/profiledef.sh"

    # --- Include merged package list in ISO for the installer ---

    mkdir -p "$AIROOTFS/usr/local/share/zephyros"

    cp "$PROFILE_TMP/packages.x86_64" "$AIROOTFS/usr/local/share/zephyros/packages.x86_64"

    # --- Copy AI wrapper script ---

    if [ -f "$BASE_DIR/airootfs/usr/local/bin/zephyros-ai" ]; then

        cp "$BASE_DIR/airootfs/usr/local/bin/zephyros-ai" "$AIROOTFS/usr/local/bin/zephyros-ai"

    fi

    # --- Copy installer and welcome script ---

    if [ -f "$BASE_DIR/airootfs/usr/local/bin/zephyros-install" ]; then

        cp "$BASE_DIR/airootfs/usr/local/bin/zephyros-install" "$AIROOTFS/usr/local/bin/zephyros-install"

    fi

    if [ -f "$BASE_DIR/airootfs/usr/local/bin/zephyros-welcome" ]; then

        cp "$BASE_DIR/airootfs/usr/local/bin/zephyros-welcome" "$AIROOTFS/usr/local/bin/zephyros-welcome"

    fi

    # --- Copy desktop entries ---

    if [ -d "$BASE_DIR/airootfs/usr/share/applications" ]; then

        mkdir -p "$AIROOTFS/usr/share/applications"

        cp -a "$BASE_DIR/airootfs/usr/share/applications/." "$AIROOTFS/usr/share/applications/"

    fi

    if [ -d "$BASE_DIR/airootfs/etc/skel/Desktop" ]; then

        mkdir -p "$AIROOTFS/etc/skel/Desktop"

        cp -a "$BASE_DIR/airootfs/etc/skel/Desktop/." "$AIROOTFS/etc/skel/Desktop/"

    fi

    if [ -d "$BASE_DIR/airootfs/etc/skel/.config" ]; then

        mkdir -p "$AIROOTFS/etc/skel/.config"

        cp -a "$BASE_DIR/airootfs/etc/skel/.config/." "$AIROOTFS/etc/skel/.config/"

    fi

    if [ -f "$BASE_DIR/airootfs/etc/skel/.zprofile" ]; then

        cp "$BASE_DIR/airootfs/etc/skel/.zprofile" "$AIROOTFS/etc/skel/.zprofile"

    fi

    # Add execute permissions for scripts

    # archiso file_permissions format: ["path"]="uid:gid:mode"

    if ! grep -q 'zephyros-firstboot' "$PROFILE_TMP/profiledef.sh"; then

        sed -i '/^file_permissions=(/a\  ["/usr/local/bin/zephyros-firstboot.sh"]="0:0:755"' \
            "$PROFILE_TMP/profiledef.sh"

    fi

    if ! grep -q 'zephyros-install' "$PROFILE_TMP/profiledef.sh"; then

        sed -i '/^file_permissions=(/a\  ["/usr/local/bin/zephyros-install"]="0:0:755"' \
            "$PROFILE_TMP/profiledef.sh"

    fi

    if ! grep -q 'zephyros-ai' "$PROFILE_TMP/profiledef.sh"; then

        sed -i '/^file_permissions=(/a\  ["/usr/local/bin/zephyros-ai"]="0:0:755"' \
            "$PROFILE_TMP/profiledef.sh"

    fi

    if ! grep -q 'zephyros-welcome' "$PROFILE_TMP/profiledef.sh"; then

        sed -i '/^file_permissions=(/a\  ["/usr/local/bin/zephyros-welcome"]="0:0:755"' \
            "$PROFILE_TMP/profiledef.sh"

    fi

    # --- Build AUR packages ---

    LOCALREPO_BUILDER="$SCRIPT_DIR/scripts/build-localrepo.sh"

    if [ -f "$LOCALREPO_BUILDER" ]; then

        log "Preparing local repo (AUR packages)..."

        if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then

            su - "$SUDO_USER" -c "sh \"$LOCALREPO_BUILDER\""

        else

            sh "$LOCALREPO_BUILDER"

        fi

    fi

    # Append local repo to profile pacman.conf if AUR packages were built
    LOCALREPO_ABS=$(cd "$SCRIPT_DIR/localrepo" 2>/dev/null && pwd || true)
    if [ -n "$LOCALREPO_ABS" ] && [ -f "$LOCALREPO_ABS/zephyros-local.db.tar.gz" ]; then
        log "Adding local repo to pacman.conf..."
        cat >>"$PROFILE_TMP/pacman.conf" <<REPOEOF

[zephyros-local]
SigLevel = Optional TrustAll
Server = file://$LOCALREPO_ABS
REPOEOF
    fi

    # --- Build ISO ---

    export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}

    log "Running mkarchiso..."

    sudo mkarchiso \
        -v \
        -w "$WORK_DIR/mkarchiso-work" \
        -o "$OUT_DIR" \
        "$PROFILE_TMP"

    log "Build complete. Output:"

    ls -lh "$OUT_DIR"/${ISO_NAME}* 2>/dev/null || true

}

main "$@"
