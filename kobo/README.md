# KOReader, Kobo fork (branch `kobo`)

Doc's Kobo Elipsa build of KOReader. Only Lua is changed; the Kobo runs
the official release this branch is based on, with the changed files
copied over it (`kobo/install.sh`).

Base: **v2026.03** (`KOREADER_BASE` in kobo/install.sh).

## Changes

- **Top menu in words, 4 tabs**: Menu · Book · Search · Settings (file
  browser: Menu · Folder · Search · Settings). The Style tab is Book >
  Style (its "Style" entry renamed Stylesheet); Settings > Frontlight is
  gone (Menu > Light; hold it for brightness). Every tab gets an
  equal slot; Menu is at the left edge. `ui/widget/touchmenu.lua`
  (TouchMenuBar), `ui/elements/kobo_menu.lua`.
- **Hold Menu** = light on/off (the tab shows ☀ when on); **hold
  Settings** = network panel (from tailscale.koplugin; the tab shows ◦
  for Wi-Fi, ● for Tailscale, DEV in Dev mode).
- **Menu** holds Light, Network, File browser, History…, **My Kobo**
  (Learning languages, ReadItEventually, KoboHub, Chess, Dev mode),
  **Tools** (every tool A–Z; was the Tools tab + More tools), Book
  status/information, Help (Menu search first), Exit.
  `ui/elements/reader_menu_order.lua`, `filemanager_menu_order.lua`.
- The interface-language list is hidden (English).
- `plugins/mykobo.koplugin`: Dev mode (no sleep, Wi-Fi kept, off by
  itself after 3 h), Wi-Fi off after 10 min unused, first-run settings
  (speed-reading plugin off, quick menu on hold top-left corner).
- **Progress sync never makes you wait** (`plugins/kosync.koplugin`):
  stock auto sync turns Wi-Fi on and waits for it on every wake, sleep
  and book close (over a minute with no network in reach). Now waking
  starts Wi-Fi in the background and pulls when it connects; sleep and
  closing a book push only when already online.

Third-party plugins on the Kobo: **Solitaire**,
github.com/Lalocaballero/solitaire.koplugin (MIT; installed at commit
9f95960, 2026-10-14), listed in My Kobo, with
`solitaire-sizes.patch` applied (`patch -p1` in the plugin
folder): on the Elipsa the status line was cut off and the rank
and suit symbols too big; now the status line fits the bar and the
screen width, and the symbols are about half their old size. MenuSorter now puts a plugin
whose sorting hint names a menu this fork lacks (e.g. "tools") in Menu >
Tools instead of failing.

The Kobo-specific plugins live in their own repos (KoboLanguage,
KoboHub, Kobo-ReadItLater, KoboTailScale, KoboChess).

## A new KOReader release

    git fetch upstream --tags
    git merge vNEW              # fix conflicts, test
    # set KOREADER_BASE=vNEW in kobo/install.sh
    # update KOReader on the Kobo to vNEW (OTA or the release zip)
    kobo/install.sh

## Undo

Copy `.adds/koreader/kobo-fork-originals/` back over `.adds/koreader/`
and delete `plugins/mykobo.koplugin`, or reinstall the official release.
