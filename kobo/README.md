# KOReader, Kobo fork (branch `kobo`)

Doc's Kobo Elipsa build of KOReader. Only Lua is changed; the Kobo runs
the official release this branch is based on, with the changed files
copied over it (`kobo/install.sh`).

Base: **v2026.03** (`KOREADER_BASE` in kobo/install.sh).

## Changes

- **Top menu in words, 5 tabs**: Menu · Book · Style · Search · Settings
  (file browser: Menu · Folder · Search · Settings). Every tab gets an
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
