# Start sway automatically when logging in on the first virtual terminal.
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    exec start-sway
fi
