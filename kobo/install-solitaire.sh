#!/bin/sh
# Assemble the patched Solitaire plugin and copy it to a Kobo over
# KOReader's SSH server (port 2222, blank password). The plugin is
# Lalocaballero/solitaire.koplugin as vendored in KoboHub (master branch),
# with solitaire-sizes.patch, solitaire-kobo.patch and solitaire-help.patch
# applied in that order (each one only if not already in the vendored copy),
# the same as KoboKit's tools/build-kit.sh. Restart KOReader afterwards.
#
#   kobo/install-solitaire.sh KOBO_IP
#   KOBOHUB=/path/to/KoboHub kobo/install-solitaire.sh KOBO_IP
set -eu
IP=${1:?"usage: $0 KOBO_IP  (the Kobo's address; KOReader shows it in Network > SSH server)"}
HERE=$(cd "$(dirname "$0")" && pwd)
KOBOHUB=${KOBOHUB:-$(cd "$HERE/../.." && pwd)/KoboHub}
KO=/mnt/onboard/.adds/koreader

kobo() {
    sshpass -p '' ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 -p 2222 "root@$IP" "$@"
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git -C "$KOBOHUB" archive master -- vendor/solitaire.koplugin | tar -x -C "$work"
plugin=$work/vendor/solitaire.koplugin
for p in solitaire-sizes.patch solitaire-kobo.patch solitaire-help.patch; do
    if patch -s -f -R --dry-run -p1 -d "$plugin" < "$HERE/$p" >/dev/null 2>&1; then
        echo "  $p already applied"
    else
        patch -s -f -p1 -d "$plugin" < "$HERE/$p"
        echo "  $p applied"
    fi
done
find "$plugin" \( -name '*.orig' -o -name '*.rej' \) -delete

# Unpack beside, check every file, then swap folders: a dropped connection
# must never leave KOReader with a half-written plugin.
files=$(cd "$plugin" && find . -type f | sort)
tar -C "$plugin" -cf - . | kobo "rm -rf $KO/plugins/.solitaire-new && mkdir -p $KO/plugins/.solitaire-new && tar -C $KO/plugins/.solitaire-new -xf -"
want=$(cd "$plugin" && for f in $files; do printf '%s %s\n' "$(md5sum < "$f" | cut -c1-32)" "$f"; done)
got=$(kobo "cd $KO/plugins/.solitaire-new && for f in $files; do printf '%s %s\\n' \"\$(md5sum < \$f | cut -c1-32)\" \"\$f\"; done")
if [ "$want" != "$got" ]; then
    echo "Copy to the Kobo was incomplete; nothing changed. Run again." >&2
    exit 1
fi
kobo "cd $KO/plugins && rm -rf .solitaire-old && { [ ! -d solitaire.koplugin ] || mv solitaire.koplugin .solitaire-old; } && mv .solitaire-new solitaire.koplugin && rm -rf .solitaire-old"
echo "Solitaire installed. Restart KOReader."
