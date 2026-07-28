#!/bin/sh
# ---------------------------------------------------------------------------
# setup-sway-overlay.sh
#
# Generates a live-build config/ overlay for a Sway-based Debian spin,
# themed Crimson / Charcoal / Gold / Ivory:
#   Primary   Deep Crimson   #8B1E24   focus, active workspace, selection
#   Secondary Charcoal Black  #1B1B1B   background everywhere
#   Accent    Antique Gold   #C8A24A   cursor, clock, prompts, warnings
#   Highlight Ivory          #F5F0E6   primary text
#
# Stack: sway + swaybg + swayidle + swaylock, waybar, wofi, foot,
#        pipewire audio, NetworkManager, mako, xdg portals, polkit.
# Login: no display manager — logging in on tty1 execs sway (works the same
#        for the live user and any user the installer creates).
#
# USAGE
#   1. sudo apt install live-build
#   2. mkdir my-distro && cd my-distro
#   3. lb config \
#        --distribution trixie \
#        --archive-areas "main contrib non-free non-free-firmware" \
#        --debian-installer live
#   4. sh /path/to/setup-sway-overlay.sh      # run from INSIDE my-distro
#   5. sudo lb build
#
# Re-runnable: overwrites the files it manages, leaves the rest alone.
#
# BINARY ASSETS (a shell script can't carry PNGs) -- copy both in before
# building, after running this script:
#   cp crimson-gold-4k.png \
#     config/includes.chroot/usr/share/backgrounds/crimson-gold.png
#   cp koboldos-logo.png \
#     config/includes.chroot/usr/share/plymouth/themes/koboldos/logo.png
#   cp koboldos-logo.png \
#     config/includes.chroot/etc/calamares/branding/koboldos/logo.png
# If either is missing the build still succeeds (wallpaper falls back to
# solid charcoal; Plymouth falls back to text). The Nerd Font is downloaded
# during the build (see the font hook) — no manual copy needed.
# ---------------------------------------------------------------------------
set -eu

if [ ! -d config ]; then
    echo "error: no ./config directory found." >&2
    echo "Run this from your live-build project root (after 'lb config')." >&2
    exit 1
fi

SKEL="config/includes.chroot/etc/skel/.config"
BIN="config/includes.chroot/usr/local/bin"

mkdir -p \
    config/package-lists \
    config/hooks/normal \
    config/includes.chroot/etc/profile.d \
    config/includes.chroot/etc/systemd/system-preset \
    "$BIN" \
    config/includes.chroot/usr/share/backgrounds \
    config/includes.chroot/usr/share/plymouth/themes/koboldos \
    config/includes.chroot/etc/default \
    config/includes.chroot/etc/calamares/branding/koboldos \
    config/includes.chroot/usr/share/applications \
    config/includes.chroot/etc/polkit-1/rules.d \
    config/includes.chroot/etc/chromium.d \
    config/includes.chroot/usr/share/fonts/truetype/nerd-fonts \
    "$SKEL/sway" "$SKEL/waybar" "$SKEL/foot" "$SKEL/wofi" "$SKEL/mako" \
    "$SKEL/swaylock" "$SKEL/gtk-3.0" "$SKEL/gtk-4.0"

# ---------------------------------------------------------------------------
# 1. Package selection
# ---------------------------------------------------------------------------
cat > config/package-lists/desktop.list.chroot <<'EOF'
# --- Wayland compositor + core session ---
sway
swaybg
swayidle
swaylock
xwayland

# --- Bar / launcher / terminal ---
waybar
wofi
foot

# --- Wayland utilities ---
wl-clipboard
grim
slurp
mako-notifier
brightnessctl
playerctl

# --- Portals (screen share, native file pickers) ---
xdg-desktop-portal
xdg-desktop-portal-wlr
xdg-desktop-portal-gtk
xdg-utils

# --- Audio (PipeWire) ---
pipewire
pipewire-pulse
wireplumber
pavucontrol

# --- Network ---
network-manager
network-manager-gnome

# --- Session bits: polkit agent ---
mate-polkit
# provides dbus-update-activation-environment (portal env propagation)
dbus-x11

# --- Fonts (Font Awesome supplies most waybar glyphs) ---
fonts-dejavu
fonts-font-awesome
fonts-noto-color-emoji

# --- GTK dark theming (so app dialogs / pavucontrol aren't default Adwaita) ---
arc-theme
papirus-icon-theme
gnome-themes-extra

# --- Boot splash ---
plymouth
# label plugin: needed for the LUKS passphrase prompt + boot-message text.
# VERIFY IT EXISTS before rebuilding (a bad package name breaks the build):
#   docker run --rm debian:trixie sh -c \
#     'apt-get update -qq && apt-get install --dry-run plymouth-label >/dev/null && echo OK'
# If that fails, the label plugin is bundled in 'plymouth' on your version —
# delete the line below.
plymouth-label

# --- Graphical installer (Calamares) ---
# VERIFY both exist in your suite before rebuilding (dry-run in a trixie
# container) so a bad name can't break the build:
#   docker run --rm debian:trixie sh -c 'apt-get update -qq && \
#     apt-get install --dry-run calamares calamares-settings-debian >/dev/null && echo OK'
calamares
calamares-settings-debian

# --- CLI tools & shell prompt ---
curl
git
starship
unzip

# --- File manager ---
pcmanfm

# --- Web browser ---
chromium

# --- Virtualisation: virt-manager GUI + libvirt system daemon + KVM/QEMU.
#     A polkit rule (section 8g) lets local desktop users manage libvirt
#     without group setup, so it works on first boot for any username. ---
libvirt-daemon
libvirt-daemon-system
qemu-system-x86
virt-manager
EOF

# ---------------------------------------------------------------------------
# 2. Session launcher — sets Wayland env vars, then execs sway.
# ---------------------------------------------------------------------------
cat > "$BIN/start-sway" <<'EOF'
#!/bin/sh
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export _JAVA_AWT_WM_NONREPARENTING=1
exec sway "$@"
EOF
chmod 755 "$BIN/start-sway"

# ---------------------------------------------------------------------------
# 3. Launch sway on tty1 login (no display manager).
#    Sourced by login shells; the tty1 guard keeps it from firing on SSH or
#    other VTs, and the WAYLAND_DISPLAY guard prevents a re-exec loop.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/profile.d/10-start-sway.sh <<'EOF'
# Start sway automatically when logging in on the first virtual terminal.
if [ "$(tty)" = "/dev/tty1" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
    exec start-sway
fi
EOF

# ---------------------------------------------------------------------------
# 4. Sway config
# ---------------------------------------------------------------------------
cat > "$SKEL/sway/config" <<'EOF'
### Variables
set $mod Mod4
set $term foot
set $menu wofi --show drun
set $left h
set $down j
set $up k
set $right l

### Appearance
font pango:DejaVu Sans 10
default_border pixel 2
gaps inner 6

### Colours — Crimson / Charcoal / Gold / Ivory
# class                 border   background text     indicator child_border
client.focused          #8B1E24  #8B1E24   #F5F0E6  #C8A24A   #8B1E24
client.focused_inactive #1B1B1B  #1B1B1B   #A89F8C  #3A3A3A   #3A3A3A
client.unfocused        #1B1B1B  #1B1B1B   #A89F8C  #1B1B1B   #2A2A2A
client.urgent           #C8A24A  #8B1E24   #F5F0E6  #C8A24A   #C8A24A

### Wallpaper. Uses the branded image if present; falls back to solid
### charcoal. (Copy crimson-gold-4k.png into the overlay before building —
### see the note in setup-sway-overlay.sh.)
output * bg /usr/share/backgrounds/crimson-gold.png fill #1B1B1B

### Idle: lock after 5 min, screen off after 10, lock before sleep
exec swayidle -w \
    timeout 300 'swaylock -f' \
    timeout 600 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' \
    before-sleep 'swaylock -f'

### Touchpad defaults (ignored on machines without one)
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
}

### Autostart
# Export the Wayland session env to D-Bus + systemd so xdg-desktop-portal
# (and other user services) activate correctly. Without this, GTK apps such
# as waybar fail portal activation for org.freedesktop.portal.Desktop.
exec systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
exec waybar
exec mako
exec nm-applet --indicator
# Polkit agent. If auth dialogs never appear, confirm the path with
#   dpkg -L mate-polkit | grep authentication-agent
exec /usr/lib/mate-polkit/polkit-mate-authentication-agent-1

### Launch / window management
bindsym $mod+Return exec $term
bindsym $mod+d exec $menu
bindsym $mod+Shift+f exec pcmanfm
bindsym $mod+Shift+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec swaynag -t warning \
    -m 'Exit sway?' -B 'Yes, exit' 'swaymsg exit'

### Focus
bindsym $mod+$left focus left
bindsym $mod+$down focus down
bindsym $mod+$up focus up
bindsym $mod+$right focus right
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

### Move
bindsym $mod+Shift+$left move left
bindsym $mod+Shift+$down move down
bindsym $mod+Shift+$up move up
bindsym $mod+Shift+$right move right

### Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

### Layout
bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+s layout stacking
bindsym $mod+w layout tabbed
bindsym $mod+e layout toggle split
bindsym $mod+f fullscreen
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle
bindsym $mod+a focus parent

### Resize mode
mode "resize" {
    bindsym $left resize shrink width 10px
    bindsym $down resize grow height 10px
    bindsym $up resize shrink height 10px
    bindsym $right resize grow width 10px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

### Screenshots (grim + slurp)
bindsym Print exec grim ~/Pictures/$(date +'%Y-%m-%d-%H%M%S').png
bindsym $mod+Print exec grim -g "$(slurp)" ~/Pictures/$(date +'%Y-%m-%d-%H%M%S').png

### Media / brightness keys
bindsym XF86AudioRaiseVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindsym XF86MonBrightnessUp exec brightnessctl set 5%+
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-
bindsym XF86AudioPlay exec playerctl play-pause
bindsym XF86AudioNext exec playerctl next
bindsym XF86AudioPrev exec playerctl previous

### Drag/resize floating windows with the mouse
floating_modifier $mod normal

### Lock screen
bindsym $mod+Ctrl+l exec swaylock -f
EOF

# ---------------------------------------------------------------------------
# 5. Waybar
# ---------------------------------------------------------------------------
cat > "$SKEL/waybar/config.jsonc" <<'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 6,
    "modules-left": [
        "sway/workspaces",
        "sway/mode"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "pulseaudio",
        "network",
        "cpu",
        "memory",
        "battery",
        "tray"
    ],
    "sway/workspaces": {
        "disable-scroll": true,
        "all-outputs": true
    },
    "clock": {
        "format": " {:%a %d %b  %H:%M}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": {
        "format": " {usage}%"
    },
    "memory": {
        "format": " {}%"
    },
    "battery": {
        "format": "{icon} {capacity}%",
        "format-icons": [
            "",
            "",
            "",
            "",
            ""
        ],
        "states": {
            "warning": 30,
            "critical": 15
        }
    },
    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": " {ipaddr}",
        "format-disconnected": " off"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": " muted",
        "format-icons": {
            "default": [
                "",
                "",
                ""
            ]
        },
        "on-click": "pavucontrol"
    },
    "tray": {
        "spacing": 8
    }
}
EOF

cat > "$SKEL/waybar/style.css" <<'EOF'
/* Crimson / Charcoal / Gold / Ivory */
* {
    font-family: "JetBrainsMono Nerd Font Mono", "Font Awesome 5 Free";
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background: #1B1B1B;
    color: #F5F0E6;
    border-bottom: 2px solid #8B1E24;
}

#workspaces button {
    padding: 0 10px;
    color: #A89F8C;
    background: transparent;
}
#workspaces button.focused {
    color: #F5F0E6;
    background: #8B1E24;
    border-bottom: 2px solid #C8A24A;
}
#workspaces button.urgent {
    color: #1B1B1B;
    background: #C8A24A;
}

#clock {
    color: #C8A24A;
    font-weight: bold;
    padding: 0 12px;
}

#cpu, #memory, #network, #pulseaudio, #tray {
    color: #F5F0E6;
    padding: 0 10px;
}

#battery { color: #F5F0E6; padding: 0 10px; }
#battery.warning  { color: #C8A24A; }
#battery.critical { color: #B0313A; }

#pulseaudio.muted { color: #A89F8C; }
EOF

# ---------------------------------------------------------------------------
# 6. Foot (full 16-colour ANSI palette; your 4 colours + derived tones)
# ---------------------------------------------------------------------------
cat > "$SKEL/foot/foot.ini" <<'EOF'
# Crimson / Charcoal / Gold / Ivory
font=JetBrainsMono Nerd Font Mono:size=11
pad=8x8

[cursor]
# text under cursor = charcoal, cursor block = antique gold
color=1B1B1B C8A24A

[colors]
background=1B1B1B
foreground=F5F0E6

selection-foreground=F5F0E6
selection-background=8B1E24

# --- normal ---
regular0=1B1B1B
regular1=8B1E24
regular2=6E7B3E
regular3=C8A24A
regular4=4E6A85
regular5=8B4A5A
regular6=4E807C
regular7=D8D2C4

# --- bright ---
bright0=3A3A3A
bright1=B0313A
bright2=8A9A50
bright3=E0BB63
bright4=6A88A5
bright5=A96578
bright6=6BA39D
bright7=F5F0E6
EOF

# ---------------------------------------------------------------------------
# 7. Wofi
# ---------------------------------------------------------------------------
cat > "$SKEL/wofi/config" <<'EOF'
show=drun
width=600
lines=8
prompt=Run
insensitive=true
allow_images=true
EOF

cat > "$SKEL/wofi/style.css" <<'EOF'
/* Crimson / Charcoal / Gold / Ivory */
window {
    background-color: #1B1B1B;
    color: #F5F0E6;
    border: 2px solid #C8A24A;
    border-radius: 8px;
    font-family: "DejaVu Sans";
    font-size: 14px;
}

#input {
    margin: 8px;
    padding: 8px;
    background-color: #2A2A2A;
    color: #F5F0E6;
    border: none;
    border-bottom: 2px solid #C8A24A;
    border-radius: 4px;
}

#inner-box { margin: 4px; }
#outer-box { margin: 4px; }
#scroll { margin: 0; }
#text { color: #F5F0E6; padding: 2px 6px; }

#entry { padding: 4px; border-radius: 4px; }
#entry:selected { background-color: #8B1E24; }
#entry:selected #text { color: #F5F0E6; font-weight: bold; }
EOF

# ---------------------------------------------------------------------------
# 8. Mako notifications
# ---------------------------------------------------------------------------
cat > "$SKEL/mako/config" <<'EOF'
background-color=#1B1B1B
text-color=#F5F0E6
border-color=#8B1E24
progress-color=over #C8A24A
border-radius=6
border-size=2
default-timeout=5000

[urgency=high]
border-color=#C8A24A
EOF

# ---------------------------------------------------------------------------
# 8b. Swaylock — crimson/gold indicator ring on charcoal
# ---------------------------------------------------------------------------
cat > "$SKEL/swaylock/config" <<'EOF'
ignore-empty-password
show-failed-attempts
indicator-radius=100
indicator-thickness=10

color=1B1B1B
inside-color=1B1B1B
inside-clear-color=1B1B1B
inside-ver-color=1B1B1B
inside-wrong-color=1B1B1B

ring-color=8B1E24
ring-clear-color=C8A24A
ring-ver-color=C8A24A
ring-wrong-color=B0313A

key-hl-color=C8A24A
bs-hl-color=B0313A

text-color=F5F0E6
text-clear-color=F5F0E6
text-ver-color=F5F0E6
text-wrong-color=F5F0E6

line-color=00000000
separator-color=00000000
EOF

# ---------------------------------------------------------------------------
# 8c. GTK dark theme (covers GTK3 apps: pavucontrol, nm dialogs, file pickers).
#     GTK4/libadwaita apps follow the portal's colour-scheme; the gtk-4.0
#     prefer-dark flag below nudges the ones that read it.
# ---------------------------------------------------------------------------
cat > "$SKEL/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=Adwaita
EOF

cat > "$SKEL/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=1
EOF

# ---------------------------------------------------------------------------
# 8d. Distro identity — /etc/os-release (neofetch, TTY banner, installer).
#     Shipped as a regular file; base-files leaves an existing file alone.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/os-release <<'EOF'
NAME="KoboldOS"
PRETTY_NAME="KoboldOS"
ID=koboldos
ID_LIKE=debian
VERSION="1.0"
VERSION_ID="1.0"
ANSI_COLOR="1;31"
HOME_URL="https://example.org/"
EOF

# ---------------------------------------------------------------------------
# 8e. Plymouth boot splash — 'script' theme. Shows the crest+name logo on
#     charcoal with a gentle pulse, renders boot messages, and (for encrypted
#     installs) a LUKS passphrase prompt. The prompt/messages use text
#     rendering, which is why plymouth-label is in the package list.
#     logo.png must be copied in before building (see header note); if it's
#     absent Plymouth falls back to text.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/usr/share/plymouth/themes/koboldos/koboldos.plymouth <<'EOF'
[Plymouth Theme]
Name=KoboldOS
Description=KoboldOS crimson/gold boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/koboldos
ScriptFile=/usr/share/plymouth/themes/koboldos/koboldos.script
EOF

cat > config/includes.chroot/usr/share/plymouth/themes/koboldos/koboldos.script <<'EOF'
# KoboldOS boot splash: logo + boot messages + LUKS passphrase prompt.

Window.SetBackgroundTopColor(0.106, 0.106, 0.106);      # charcoal
Window.SetBackgroundBottomColor(0.071, 0.071, 0.071);

sw = Window.GetWidth();
sh = Window.GetHeight();

# Logo, scaled to at most half the screen height, centred in the upper third
logo.image = Image("logo.png");
lw = logo.image.GetWidth();
lh = logo.image.GetHeight();
maxh = sh * 0.5;
if (lh > maxh) {
    logo.image = logo.image.Scale(lw * maxh / lh, maxh);
}
logo.y = sh * 0.30 - logo.image.GetHeight() / 2;
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(sw / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(logo.y);
logo.bottom = logo.y + logo.image.GetHeight();

# Gentle opacity pulse
tick = 0;
fun refresh() {
    tick = tick + 1;
    logo.sprite.SetOpacity(0.8 + 0.2 * Math.Sin(tick / 25));
}
Plymouth.SetRefreshFunction(refresh);

# Boot messages near the bottom (ivory)
msg.sprite = Sprite();
fun message_callback(text) {
    msg.image = Image.Text(text, 0.96, 0.94, 0.90);
    msg.sprite.SetImage(msg.image);
    msg.sprite.SetX(sw / 2 - msg.image.GetWidth() / 2);
    msg.sprite.SetY(sh - 80);
    msg.sprite.SetZ(10);
}
Plymouth.SetMessageFunction(message_callback);

# LUKS / password prompt (hidden until requested)
prompt.sprite = Sprite();
bullets.sprite = Sprite();
prompt.sprite.SetOpacity(0);
bullets.sprite.SetOpacity(0);

fun display_password_callback(text, count) {
    p = Image.Text(text, 0.96, 0.94, 0.90);            # ivory prompt
    prompt.sprite.SetImage(p);
    prompt.sprite.SetX(sw / 2 - p.GetWidth() / 2);
    prompt.sprite.SetY(logo.bottom + sh * 0.12);
    prompt.sprite.SetZ(10);
    prompt.sprite.SetOpacity(1);

    dots = "";
    for (i = 0; i < count; i = i + 1) {
        dots = dots + "*";
    }
    b = Image.Text(dots, 0.78, 0.63, 0.29);            # gold bullets
    bullets.sprite.SetImage(b);
    bullets.sprite.SetX(sw / 2 - b.GetWidth() / 2);
    bullets.sprite.SetY(logo.bottom + sh * 0.12 + 46);
    bullets.sprite.SetZ(10);
    bullets.sprite.SetOpacity(1);
}
Plymouth.SetDisplayPasswordFunction(display_password_callback);

fun normal_callback() {
    prompt.sprite.SetOpacity(0);
    bullets.sprite.SetOpacity(0);
}
Plymouth.SetDisplayNormalFunction(normal_callback);
EOF

# ---------------------------------------------------------------------------
# 8f. GRUB default — enable the splash on the installed system.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="KoboldOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
EOF

# ---------------------------------------------------------------------------
# 8g. Calamares branding. We reuse calamares-settings-debian's working module
#     sequence and override only the branding component with KoboldOS. The
#     hook (section 9) points settings.conf at this branding.
#     logo.png must be copied in before building (see header note).
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/calamares/branding/koboldos/branding.desc <<'EOF'
---
componentName: koboldos

welcomeStyleCalamares: true
welcomeExpandingLogo: true
windowExpanding: normal
windowSize: 820px,540px
windowPlacement: center

strings:
    productName:         "KoboldOS"
    shortProductName:    "KoboldOS"
    version:             "1.0"
    shortVersion:        "1.0"
    versionedName:       "KoboldOS 1.0"
    shortVersionedName:  "KoboldOS 1.0"
    bootloaderEntryName:  "KoboldOS"
    productUrl:          "https://example.org/"
    supportUrl:          "https://example.org/"
    knownIssuesUrl:      "https://example.org/"
    releaseNotesUrl:     "https://example.org/"

images:
    productLogo:    "logo.png"
    productIcon:    "logo.png"

slideshow:      "show.qml"
slideshowAPI: 2

style:
    sidebarBackground:    "#1B1B1B"
    sidebarText:          "#F5F0E6"
    sidebarTextSelect:    "#C8A24A"
    sidebarTextHighlight: "#8B1E24"
EOF

cat > config/includes.chroot/etc/calamares/branding/koboldos/show.qml <<'EOF'
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    function onActivate()   { presentation.currentSlide = 0; }
    function onLeave()      { }

    Slide {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: 24
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "logo.png"
                width: 320
                fillMode: Image.PreserveAspectFit
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Installing KoboldOS…"
                color: "#F5F0E6"
                font.pixelSize: 24
            }
        }
    }

    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            width: parent.width * 0.8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "A lean Wayland desktop — Sway, Waybar, and Foot — forged on Debian."
            color: "#C8A24A"
            font.pixelSize: 22
        }
    }
}
EOF

cat > config/includes.chroot/etc/calamares/branding/koboldos/stylesheet.qss <<'EOF'
/* KoboldOS — crimson / charcoal / gold / ivory (kept light to avoid
   breaking Calamares' layout; colours only) */
QWidget            { color: #F5F0E6; }
QLabel             { color: #F5F0E6; }
QPushButton {
    background-color: #8B1E24;
    color: #F5F0E6;
    border: 1px solid #C8A24A;
    border-radius: 4px;
    padding: 6px 14px;
}
QPushButton:hover    { background-color: #C8A24A; color: #1B1B1B; }
QPushButton:disabled { background-color: #3A3A3A; color: #A89F8C; border-color: #3A3A3A; }
EOF

# Branded launcher (shows in wofi). Forces the Qt xcb platform so Calamares
# runs under XWayland — avoids needing a qtwayland package on the Sway session.
cat > config/includes.chroot/usr/share/applications/install-koboldos.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Install KoboldOS
GenericName=System Installer
Comment=Install KoboldOS to your computer
Exec=pkexec /usr/bin/calamares -platform xcb
Icon=/etc/calamares/branding/koboldos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=install;installer;calamares;
EOF

# Let the live session launch the installer via pkexec without a password
# prompt. Scoped to the calamares binary only.
cat > config/includes.chroot/etc/polkit-1/rules.d/49-koboldos-calamares.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        action.lookup("program") == "/usr/bin/calamares" &&
        subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF

# Let local, active desktop sessions manage libvirt (qemu:///system) without
# 'libvirt' group membership or a password prompt — standard for a single-user
# desktop, and works for any username on both live and installed systems.
cat > config/includes.chroot/etc/polkit-1/rules.d/50-koboldos-libvirt.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active) {
        return polkit.Result.YES;
    }
});
EOF

# ---------------------------------------------------------------------------
# 8h. Starship prompt config, shipped to every user via /etc/skel. The hook
#     (section 9) appends the shell init line to /etc/skel/.bashrc.
#     Crimson is a powerline banner behind the directory; gold/ivory carry the
#     foreground. Uses Nerd Font glyphs (JetBrainsMono Nerd Font Mono, shipped
#     in section 1 + the font hook).
# ---------------------------------------------------------------------------
cat > "$SKEL/starship.toml" <<'EOF'
"$schema" = 'https://starship.rs/config-schema.json'

add_newline = true

format = """
[╭─◆ ](bold #C8A24A)$username$hostname$directory$git_branch$git_status$cmd_duration$nodejs$python$rust$golang
[╰─](bold #C8A24A)$character"""

[character]
success_symbol = "[❯](bold #C8A24A)"
error_symbol   = "[❯](bold #B0313A)"
vimcmd_symbol  = "[❮](bold #C8A24A)"

[username]
show_always = true
style_user = "bold #C8A24A"
style_root = "bold #B0313A"
format = "[$user]($style)"

[hostname]
ssh_only = false
style = "#A89F8C"
format = "[@$hostname]($style) "

[directory]
style = "fg:#F5F0E6 bg:#8B1E24"
read_only = " ×"
read_only_style = "fg:#F5F0E6 bg:#8B1E24"
truncation_length = 4
truncation_symbol = "…/"
format = "[](fg:#8B1E24)[ $path$read_only ](bold $style)[](fg:#8B1E24) "

[git_branch]
symbol = " "
style = "bold #C8A24A"
format = "[$symbol$branch]($style) "

[git_status]
style = "#B0313A"
format = "([$all_status$ahead_behind]($style)) "
conflicted = "✗"
ahead = "↑${count}"
behind = "↓${count}"
diverged = "↕↑${ahead_count}↓${behind_count}"
untracked = "?${count}"
modified = "●${count}"
staged = "+${count}"
renamed = "»${count}"
deleted = "✘${count}"
stashed = "≡"

[cmd_duration]
min_time = 2000
style = "#A89F8C"
format = "[took $duration]($style) "

[nodejs]
symbol = " "
style = "#6E7B3E"
format = "[$symbol($version )]($style)"

[python]
symbol = " "
style = "#6E7B3E"
format = "[$symbol($version )]($style)"

[rust]
symbol = " "
style = "#C8A24A"
format = "[$symbol($version )]($style)"

[golang]
symbol = " "
style = "#6E7B3E"
format = "[$symbol($version )]($style)"
EOF

# ---------------------------------------------------------------------------
# 8i. Chromium: prefer native Wayland (crisper on HiDPI, proper fractional
#     scaling) and fall back to XWayland automatically. Debian's chromium
#     launcher sources shell snippets from /etc/chromium.d/*.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/chromium.d/wayland <<'EOF'
export CHROMIUM_FLAGS="$CHROMIUM_FLAGS --ozone-platform-hint=auto"
EOF

# ---------------------------------------------------------------------------
# 9. Enable NetworkManager. No display manager to enable — sway is started
#    by the tty1 profile.d snippet, so a multi-user (text) boot is fine and
#    there's no graphical.target dependency to satisfy.
# ---------------------------------------------------------------------------
cat > config/includes.chroot/etc/systemd/system-preset/80-sway-desktop.preset <<'EOF'
enable NetworkManager.service
EOF

cat > config/hooks/normal/0100-services.hook.chroot <<'EOF'
#!/bin/sh
set -e
systemctl enable NetworkManager
# includes.chroot does not reliably preserve the +x bit across live-build
# versions, so guarantee the sway launcher is executable in the built image.
chmod 0755 /usr/local/bin/start-sway
# Make the KoboldOS splash the default and bake it into the initramfs.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R koboldos
fi
# Point Calamares at the KoboldOS branding component.
if [ -f /etc/calamares/settings.conf ]; then
    sed -i 's/^branding:.*/branding: koboldos/' /etc/calamares/settings.conf
fi
# Enable the Starship prompt for every new user (idempotent).
if ! grep -q 'starship init bash' /etc/skel/.bashrc 2>/dev/null; then
    echo 'eval "$(starship init bash)"' >> /etc/skel/.bashrc
fi
# --- Nerd Font: download at build time (avoids shipping/copying a binary
#     .ttf, which is easy to corrupt in transfer). Needs network + curl +
#     unzip during the build. Non-fatal: a failed download warns rather than
#     aborting the whole build. ---
NF_DIR=/usr/share/fonts/truetype/nerd-fonts
NF_VER=v3.3.0
NF_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VER}/JetBrainsMono.zip"
if command -v curl >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
    _nftmp="$(mktemp -d)"
    if curl -fsSL -o "$_nftmp/jbm.zip" "$NF_URL"; then
        mkdir -p "$NF_DIR"
        # install only the Mono (single-cell icon) weights we actually use
        unzip -o -j "$_nftmp/jbm.zip" \
            'JetBrainsMonoNerdFontMono-Regular.ttf' \
            'JetBrainsMonoNerdFontMono-Bold.ttf' \
            'JetBrainsMonoNerdFontMono-Italic.ttf' \
            'JetBrainsMonoNerdFontMono-BoldItalic.ttf' \
            -d "$NF_DIR" >/dev/null 2>&1 || true
    else
        echo "WARNING: Nerd Font download failed ($NF_URL) — glyphs will be tofu." >&2
    fi
    rm -rf "$_nftmp"
else
    echo "WARNING: curl/unzip missing — Nerd Font not installed." >&2
fi
# Clear the system font cache so it rebuilds fresh on first boot with the font
# present (building it here can bake a stale cache before fonts are in place).
rm -rf /var/cache/fontconfig/* 2>/dev/null || true
EOF
chmod 755 config/hooks/normal/0100-services.hook.chroot

# ---------------------------------------------------------------------------
# 10. Live-boot config — make the Plymouth splash appear on the LIVE ISO too.
#     Installed systems get 'quiet splash' from /etc/default/grub (section 8f);
#     the live boot takes its kernel cmdline from LB_BOOTAPPEND_LIVE in
#     config/binary, so append 'quiet splash' there if it isn't already set.
#     (Equivalent to passing --bootappend-live to 'lb config'.)
# ---------------------------------------------------------------------------
if [ -f config/binary ]; then
    if grep -q '^LB_BOOTAPPEND_LIVE=' config/binary; then
        if ! grep -q '^LB_BOOTAPPEND_LIVE=.*splash' config/binary; then
            sed -i 's/^\(LB_BOOTAPPEND_LIVE="[^"]*\)"/\1 quiet splash"/' config/binary
            echo "Patched config/binary: added 'quiet splash' to live boot cmdline."
        else
            echo "config/binary already has splash in the live cmdline; leaving it."
        fi
    else
        echo "note: LB_BOOTAPPEND_LIVE not found in config/binary — set the live"
        echo "      boot append manually, e.g. re-run lb config with:"
        echo '        --bootappend-live "boot=live components quiet splash"'
    fi
fi

echo "Overlay written. Next: sudo lb build"
