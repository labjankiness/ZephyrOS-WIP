#!/usr/bin/env sh
#
# apply-theme.sh - Apply ZephyrOS UI theming and dotfiles
#
# This script is intended to be run inside a ZephyrOS session to install:
#   - Wayfire, panel, Wofi, Kitty, and zsh configs from dotfiles/
#   - Basic GTK/theming defaults (light/dark toggle stub)

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

DOTFILES_DIR="$ROOT_DIR/dotfiles"

TARGET_USER_HOME=${TARGET_USER_HOME:-"$HOME"}

HAVE_GSETTINGS=0

log() {
    printf '%s\n' "$*" >&2
}

usage() {
    cat >&2 <<EOF
Usage: $0 [--light|--dark]

Environment:
  TARGET_USER_HOME  Target home directory (default: \$HOME)
EOF
    exit 1
}

detect_gsettings() {
    if command -v gsettings >/dev/null 2>&1; then
        if gsettings list-schemas >/dev/null 2>&1; then
            HAVE_GSETTINGS=1
            return 0
        fi
    fi
    HAVE_GSETTINGS=0
    return 1
}

gsettings_safe() {
    if [ "$HAVE_GSETTINGS" -ne 1 ]; then
        return 0
    fi
    # shellcheck disable=SC2068
    gsettings $@ || {
        log "Warning: gsettings $* failed; skipping."
        return 0
    }
}

copy_safe() {
    SRC=$1
    DEST=$2

    if [ ! -f "$SRC" ]; then
        return
    fi

    DEST_DIR=$(dirname "$DEST")
    mkdir -p "$DEST_DIR"
    cp "$SRC" "$DEST"
}

apply_light_overrides() {
    WAYFIRE_CONF="$TARGET_USER_HOME/.config/wayfire.ini"
    PANEL_CONF="$TARGET_USER_HOME/.config/wf-panel-pi/panel.ini"
    WOFI_STYLE="$TARGET_USER_HOME/.config/wofi/style.css"

    for f in "$WAYFIRE_CONF" "$PANEL_CONF" "$WOFI_STYLE"; do
        if [ -f "$f" ]; then
            sed -i \
                -e 's/rgba(24,24,24,200)/rgba(240,240,245,210)/g' \
                -e 's/rgba(20,20,25,0.80)/rgba(245,245,250,0.90)/g' \
                "$f"
        fi
    done
}

write_cursor_files() {
    CURSOR_NAME="Bibata-Modern-Classic"

    GTK3_DIR="$TARGET_USER_HOME/.config/gtk-3.0"
    GTK3_SETTINGS="$GTK3_DIR/settings.ini"
    mkdir -p "$GTK3_DIR"
    if [ ! -f "$GTK3_SETTINGS" ]; then
        cat >"$GTK3_SETTINGS" <<EOF
[Settings]
gtk-cursor-theme-name=$CURSOR_NAME
EOF
    else
        if grep -q '^gtk-cursor-theme-name=' "$GTK3_SETTINGS"; then
            sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$CURSOR_NAME/" "$GTK3_SETTINGS"
        else
            printf '%s\n' "gtk-cursor-theme-name=$CURSOR_NAME" >>"$GTK3_SETTINGS"
        fi
    fi

    ICONS_DEFAULT_DIR="$TARGET_USER_HOME/.icons/default"
    ICONS_DEFAULT_INDEX="$ICONS_DEFAULT_DIR/index.theme"
    mkdir -p "$ICONS_DEFAULT_DIR"
    cat >"$ICONS_DEFAULT_INDEX" <<EOF
[Icon Theme]
Name=$CURSOR_NAME
Inherits=$CURSOR_NAME
EOF
}

apply_gtk_theming() {
    MODE=$1

    if [ "$HAVE_GSETTINGS" -ne 1 ]; then
        log "Warning: gsettings not available or no D-Bus session; skipping GTK/icon/font/cursor theming."
        return 0
    fi

    case "$MODE" in
        light)
            GTK_THEME="adw-gtk3"
            ICON_THEME="Fluent-light"
            ;;
        *)
            GTK_THEME="adw-gtk3-dark"
            ICON_THEME="Fluent-dark"
            ;;
    esac

    if command -v fc-list >/dev/null 2>&1; then
        if fc-list ':family=Inter' >/dev/null 2>&1; then
            FONT_NAME="Inter 10"
        elif fc-list ':family=Noto Sans' >/dev/null 2>&1; then
            FONT_NAME="Noto Sans 10"
        else
            FONT_NAME="Inter 10"
        fi
    else
        FONT_NAME="Inter 10"
    fi

    gsettings_safe set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
    gsettings_safe set org.gnome.desktop.interface icon-theme "$ICON_THEME"
    gsettings_safe set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"
    gsettings_safe set org.gnome.desktop.interface font-name "$FONT_NAME"

    write_cursor_files
}

main() {
    MODE="dark"
    if [ "$#" -gt 1 ]; then
        usage
    fi
    if [ "$#" -eq 1 ]; then
        case "$1" in
            --light) MODE="light" ;;
            --dark) MODE="dark" ;;
            *) usage ;;
        esac
    fi

    log "Applying ZephyrOS theme for user home: $TARGET_USER_HOME (mode: $MODE)"

    detect_gsettings || :

    # Wayfire
    copy_safe "$DOTFILES_DIR/wayfire/wayfire.ini" "$TARGET_USER_HOME/.config/wayfire.ini"

    # Panel
    copy_safe "$DOTFILES_DIR/wf-panel-pi/panel.ini" "$TARGET_USER_HOME/.config/wf-panel-pi/panel.ini"

    # Wofi
    copy_safe "$DOTFILES_DIR/wofi/config" "$TARGET_USER_HOME/.config/wofi/config"
    copy_safe "$DOTFILES_DIR/wofi/style.css" "$TARGET_USER_HOME/.config/wofi/style.css"

    # Kitty
    copy_safe "$DOTFILES_DIR/kitty/kitty.conf" "$TARGET_USER_HOME/.config/kitty/kitty.conf"

    # zsh
    if [ -f "$DOTFILES_DIR/zsh/.zshrc" ]; then
        mkdir -p "$TARGET_USER_HOME"
        cp "$DOTFILES_DIR/zsh/.zshrc" "$TARGET_USER_HOME/.zshrc"
    fi

    if [ "$MODE" = "light" ]; then
        apply_light_overrides
    fi

    apply_gtk_theming "$MODE"

    log "Theme application complete."
}

main "$@"

