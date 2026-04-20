#!/usr/bin/env sh
#
# zephyros-firstboot.sh — First-boot setup for ZephyrOS editions
#
# This script runs once after installation via a systemd oneshot service.
# It reads /etc/zephyros-edition.conf to determine which AI model to pull
# and any edition-specific setup to perform.
#
set -eu

CONF="/etc/zephyros-edition.conf"
STAMP="/var/lib/zephyros/.firstboot-done"

log() {
    printf '[zephyros-firstboot] %s\n' "$*" | tee -a /var/log/zephyros-firstboot.log >&2
}

if [ -f "$STAMP" ]; then
    log "First boot already completed. Exiting."
    exit 0
fi

if [ ! -f "$CONF" ]; then
    log "No edition config found at $CONF. Skipping."
    mkdir -p "$(dirname "$STAMP")"
    touch "$STAMP"
    exit 0
fi

# shellcheck source=/dev/null
. "$CONF"

# --- Enable and start Ollama service ---
log "Enabling Ollama service..."
systemctl enable --now ollama.service || log "Warning: could not start ollama"

# Wait for Ollama to become ready
RETRIES=30
while [ "$RETRIES" -gt 0 ]; do
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        break
    fi
    sleep 2
    RETRIES=$((RETRIES - 1))
done

if [ "$RETRIES" -eq 0 ]; then
    log "Warning: Ollama did not become ready within 60s. Model pull may fail."
fi

# --- Pull the edition's bundled model ---
if [ -n "${OLLAMA_MODEL:-}" ]; then
    log "Pulling AI model: $OLLAMA_MODEL (this may take a while)..."
    ollama pull "$OLLAMA_MODEL" && log "Model ready: $OLLAMA_MODEL" \
        || log "Warning: failed to pull $OLLAMA_MODEL. Run 'ollama pull $OLLAMA_MODEL' manually."
else
    log "No model configured for this edition. Skipping pull."
fi

# --- Run edition-specific setup if present ---
EDITION_SETUP="/usr/local/lib/zephyros/edition-setup.sh"
if [ -x "$EDITION_SETUP" ]; then
    log "Running edition-specific setup..."
    "$EDITION_SETUP" || log "Warning: edition setup script returned non-zero."
fi

# --- Mark first boot complete ---
mkdir -p "$(dirname "$STAMP")"
touch "$STAMP"
log "First boot setup complete."
