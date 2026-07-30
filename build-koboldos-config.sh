#!/bin/sh
# ---------------------------------------------------------------------------
# build-koboldos-config.sh — turn the live-build overlay into ONE .deb:
#   * a metapackage (Depends on the whole desktop, derived from the package
#     list), so `apt install koboldos-config` gives the full system, and
#   * all branding/config files (everything under config/includes.chroot).
#
# Run from your live-build project root, AFTER setup-sway-overlay.sh and after
# copying the PNG assets into config/includes.chroot (so they ride in the deb):
#
#   sh build-koboldos-config.sh [version]      # default version 1.0
#
# Then publish it:
#   reprepro -b ~/koboldos-repo includedeb koboldos koboldos-config_1.0_all.deb
# ---------------------------------------------------------------------------
set -eu
VER="${1:-1.0}"
PROJ="$(pwd)"
INC="$PROJ/config/includes.chroot"
PKGLIST="$PROJ/config/package-lists/desktop.list.chroot"

[ -d "$INC" ]     || { echo "error: $INC not found — run setup-sway-overlay.sh first" >&2; exit 1; }
[ -f "$PKGLIST" ] || { echo "error: $PKGLIST not found" >&2; exit 1; }
command -v dpkg-deb >/dev/null 2>&1 || { echo "error: dpkg-deb missing (install dpkg-dev)" >&2; exit 1; }

BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

# 1) payload = the includes.chroot tree (already rooted at /)
cp -a "$INC/." "$BUILD/"

# 2) Rework files that another package already owns (avoid dpkg conflicts):
#    /etc/os-release is base-files' — write it from postinst instead.
rm -f "$BUILD/etc/os-release"
#    /etc/default/grub is grub-common's conffile — ship a grub.d drop-in.
if [ -f "$BUILD/etc/default/grub" ]; then
    mkdir -p "$BUILD/etc/default/grub.d"
    grep -E '^GRUB_(DISTRIBUTOR|CMDLINE_LINUX_DEFAULT)=' "$BUILD/etc/default/grub" \
        > "$BUILD/etc/default/grub.d/koboldos.cfg" || true
    rm -f "$BUILD/etc/default/grub"
fi

# 3) Depends = every real package from the build's package list
DEPS=$(grep -vE '^[[:space:]]*#' "$PKGLIST" | grep -vE '^[[:space:]]*$' \
       | grep -v '^koboldos-config$' | sed 's/[[:space:]]*$//' | paste -sd, - | sed 's/,/, /g')

# 4) control
mkdir -p "$BUILD/DEBIAN"
cat > "$BUILD/DEBIAN/control" <<EOF
Package: koboldos-config
Version: $VER
Architecture: all
Maintainer: KoboldOS <repo@koboldos.example>
Section: metapackages
Priority: optional
Depends: $DEPS
Description: KoboldOS desktop configuration and metapackage
 Pulls in the full KoboldOS Sway desktop via Depends and ships all branding,
 themes, dotfiles (/etc/skel), the Plymouth theme, Calamares branding and
 polkit rules. Bump the version and rebuild to push config updates via apt.
EOF

# 5) postinst — the runtime setup that used to live in the live-build hook
cat > "$BUILD/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    # distro identity (replace base-files' symlink with our file)
    rm -f /etc/os-release
    cat > /etc/os-release <<'OSR'
NAME="KoboldOS"
PRETTY_NAME="KoboldOS"
ID=koboldos
ID_LIKE=debian
VERSION="1.0"
VERSION_ID="1.0"
ANSI_COLOR="1;31"
HOME_URL="https://example.org/"
OSR

    [ -f /usr/local/bin/start-sway ] && chmod 0755 /usr/local/bin/start-sway || true

    if [ -x /usr/bin/systemctl ]; then
        systemctl enable NetworkManager.service >/dev/null 2>&1 || true
    fi

    if [ -f /etc/skel/.bashrc ] && ! grep -q 'starship init bash' /etc/skel/.bashrc; then
        echo 'eval "$(starship init bash)"' >> /etc/skel/.bashrc
    fi

    if [ -f /etc/calamares/settings.conf ]; then
        sed -i 's/^branding:.*/branding: koboldos/' /etc/calamares/settings.conf || true
    fi

    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        plymouth-set-default-theme -R koboldos >/dev/null 2>&1 || true
    fi

    command -v update-grub >/dev/null 2>&1 && update-grub >/dev/null 2>&1 || true
    rm -rf /var/cache/fontconfig/* 2>/dev/null || true
fi
exit 0
EOF
chmod 0755 "$BUILD/DEBIAN/postinst"

OUT="$PROJ/koboldos-config_${VER}_all.deb"
dpkg-deb --build --root-owner-group "$BUILD" "$OUT"
echo "Built $OUT"
echo
echo "Depends pulled from the package list:"
echo "  $DEPS" | fold -s -w 76 | sed 's/^/    /'
echo
echo "Publish:  reprepro -b ~/koboldos-repo includedeb koboldos \"$OUT\""
