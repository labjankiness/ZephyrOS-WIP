#!/usr/bin/env sh
#
# test-secureboot.sh - Validate Secure Boot state inside the ZephyrOS VM

set -eu

log() {
    printf '%s\n' "$*" >&2
}

pass() {
    log "PASS: $*"
}

fail() {
    log "FAIL: $*"
}

check_uefi() {
    if [ -d /sys/firmware/efi ]; then
        pass "System booted in UEFI mode."
    else
        fail "System did not boot in UEFI mode (/sys/firmware/efi missing)."
    fi
}

check_secureboot_state() {
    if command -v mokutil >/dev/null 2>&1; then
        STATE=$(mokutil --sb-state 2>/dev/null || true)
        log "mokutil --sb-state: $STATE"
        case "$STATE" in
            *"SecureBoot enabled"*)
                pass "Secure Boot appears ENABLED."
                ;;
            *)
                fail "Secure Boot is not reported as enabled."
                ;;
        esac
    else
        fail "mokutil not installed; cannot query Secure Boot state."
    fi
}

check_kernel_signature() {
    if command -v dmesg >/dev/null 2>&1; then
        if dmesg | grep -qi "Secure boot enabled"; then
            pass "Kernel dmesg indicates Secure Boot is enabled."
        else
            log "NOTE: dmesg does not clearly show 'Secure boot enabled'; this may depend on distro/kernel."
        fi
    fi
}

check_module_loading() {
    SIGNED_MOD=${1:-}
    UNSIGNED_MOD=${2:-}

    if [ -z "$SIGNED_MOD" ] || [ -z "$UNSIGNED_MOD" ]; then
        log "Module signing test skipped (no signed/unsigned module paths provided)."
        log "Usage for module test:"
        log "  $0 /path/to/signed.ko /path/to/unsigned.ko"
        return 0
    fi

    if ! [ -f "$SIGNED_MOD" ]; then
        fail "Signed module not found: $SIGNED_MOD"
        return 1
    fi
    if ! [ -f "$UNSIGNED_MOD" ]; then
        fail "Unsigned module not found: $UNSIGNED_MOD"
        return 1
    fi

    log "Testing signed module load..."
    if insmod "$SIGNED_MOD" 2>/tmp/zephyros_signed_mod.err; then
        pass "Signed module loaded successfully."
        rmmod "$(basename "$SIGNED_MOD" .ko)" 2>/dev/null || true
    else
        fail "Signed module failed to load. Error:"
        cat /tmp/zephyros_signed_mod.err >&2 || true
    fi

    log "Testing unsigned module load (should fail if enforcement works)..."
    if insmod "$UNSIGNED_MOD" 2>/tmp/zephyros_unsigned_mod.err; then
        log "Unsigned module loaded; module signature enforcement may not be active."
        rmmod "$(basename "$UNSIGNED_MOD" .ko)" 2>/dev/null || true
    else
        if grep -qi "Required key not available" /tmp/zephyros_unsigned_mod.err 2>/dev/null; then
            pass "Unsigned module rejected with 'Required key not available' (good)."
        else
            log "Unsigned module failed to load, but not due to key error:"
            cat /tmp/zephyros_unsigned_mod.err >&2 || true
        fi
    fi
}

main() {
    log "=== ZephyrOS Secure Boot Test ==="
    check_uefi
    check_secureboot_state
    check_kernel_signature
    check_module_loading "$@"
    log "=== Secure Boot test complete ==="
}

main "$@"

