# ZephyrOS Live Session
# Auto-start Wayfire on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec wayfire
fi
