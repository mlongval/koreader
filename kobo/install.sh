#!/bin/sh
# Install the Kobo fork's changes on a Kobo that runs the official KOReader
# release this branch is based on (KOREADER_BASE below). Only the Lua files
# this branch changes or adds are copied; KOReader's compiled parts stay
# the official ones. The first install keeps the originals in
# .adds/koreader/kobo-fork-originals/. Restart KOReader afterwards.
#
#   kobo/install.sh [IP]          (KOReader's SSH server, port 2222)
set -eu
KOREADER_BASE=v2026.03
IP=${1:-100.118.103.93}
cd "$(dirname "$0")/.."
KO=/mnt/onboard/.adds/koreader

kobo() {
    sshpass -p '' ssh -o ConnectTimeout=10 -o ServerAliveInterval=5 -p 2222 "root@$IP" "$@"
}

rev=$(kobo "cat $KO/git-rev")
case "$rev" in
    "$KOREADER_BASE"*) ;;
    *) echo "The Kobo runs KOReader $rev; this branch is based on $KOREADER_BASE." >&2
       echo "Merge that release into the branch first (see kobo/README.md)." >&2
       exit 1 ;;
esac

files=$(git diff --name-only --diff-filter=AM "$KOREADER_BASE" HEAD -- frontend plugins | tr "\n" " ")
gone=$(git diff --name-only --diff-filter=D "$KOREADER_BASE" HEAD -- frontend plugins | tr "\n" " ")
echo "$files" | tr " " "\n" | sed "s/^/  /"

# keep the originals once
kobo "cd $KO && mkdir -p kobo-fork-originals && for f in $files; do
        [ -e \"\$f\" ] && [ ! -e \"kobo-fork-originals/\$f\" ] &&
        mkdir -p \"kobo-fork-originals/\$(dirname \"\$f\")\" && cp -p \"\$f\" \"kobo-fork-originals/\$f\"; done; true"
# Unpack beside, check every file, then move into place: a dropped
# connection must never leave KOReader with a half-written file.
tar -cf - $files | kobo "rm -rf $KO/.kobo-fork-new && mkdir -p $KO/.kobo-fork-new && tar -C $KO/.kobo-fork-new -xf -"
want=$(for f in $files; do printf '%s %s\n' "$(md5sum < "$f" | cut -c1-32)" "$f"; done)
got=$(kobo "cd $KO/.kobo-fork-new && for f in $files; do printf '%s %s\\n' \"\$(md5sum < \$f | cut -c1-32)\" \"\$f\"; done")
if [ "$want" != "$got" ]; then
    echo "Copy to the Kobo was incomplete; nothing changed. Run again." >&2
    exit 1
fi
kobo "cd $KO/.kobo-fork-new && for f in $files; do mkdir -p \"$KO/\$(dirname \$f)\" && mv -f \"\$f\" \"$KO/\$f\"; done && cd $KO && rm -rf .kobo-fork-new"
[ -n "${gone# }" ] && kobo "cd $KO && rm -f $gone"
git describe --always --dirty | kobo "cat > $KO/kobo-fork-version"
echo "Installed $(git describe --always --dirty). Restart KOReader."
