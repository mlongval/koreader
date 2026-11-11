# KOReader, Kobo fork (branch `kobo`)

> **Part of [KoboKit](https://github.com/mlongval/KoboKit)**, a small app system for Kobo e-readers built
> on KOReader. **Start there** for simple installation instructions.
>
> ⚠️ **Written by an AI, no warranty.** This code was written almost
> entirely by Claude (Anthropic's AI). It comes with no guarantee of any
> kind, including fitness for any purpose. It may crash, lose your data,
> or stop your Kobo from working. That would not be my fault. Read the
> [disclaimer](https://github.com/mlongval/KoboKit/blob/main/DISCLAIMER.md) and back up your Kobo first.

A Kobo Elipsa build of KOReader (part of KoboKit). Only Lua is changed; the Kobo runs
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
- **Menu** holds **Home** (the Launcher, github.com/mlongval/KoboLauncher),
  Light, Network, File browser, History…, **My Kobo**
  (Learning languages, ReadItEventually, KoboHub, Notan, Chess, Solitaire,
  Home screen when KOReader starts, Dev mode),
  **Tools** (every tool A–Z; was the Tools tab + More tools), Book
  status/information, Help (Menu search first), Exit.
  `ui/elements/reader_menu_order.lua`, `filemanager_menu_order.lua`.
- The interface-language list is hidden (English).
- `plugins/mykobo.koplugin`: Dev mode (no sleep, Wi-Fi kept, off by
  itself after 3 h), Wi-Fi off after 10 min unused, first-run settings
  (speed-reading plugin off, quick menu on hold top-left corner).
- **The device menu** (`plugins/mykobo.koplugin/kobo_devicemenu.lua`): one
  list for the whole system, opened by a swipe down from the top edge in
  every app (Home, Notan, Chess, Solitaire, History; on Home also a tap on
  the clock), and shown as the first items of KOReader's own Menu tab
  (mykobo registers them as `kobo_<key>`; the old Light, Night mode,
  Network, Home and Exit entries are hidden). Order: the app's own items ·
  Light (hold: brightness), Night mode · Wi-Fi, Network…, Check KoboHub,
  Dev mode · Home, Go to Kobo · Sleep, Restart Launcher, Restart Kobo, Shut
  down Kobo (the last two and Go to Kobo ask first). The tab shows the
  app, the time and the battery. An app uses it with
  `pcall(require, "kobo_devicemenu")`.
- **The light by a drag, in every app** (`DeviceMenu.lightGesture`): one
  finger up or down along the left edge, or two fingers up or down anywhere,
  as the Reader's own gestures do (it sends KOReader's ChangeFlIntensity).
  Apps call `DeviceMenu.handleSwipe(ges, opts)` (menu or light) from their
  swipe handler.
- **In a book, the menu is for reading** (step 4 of
  KoboLauncher/PROPOSAL.md): **Menu** = the device items, Home, *Close
  book* (Books comes up); **Book** = contents, bookmarks, Style, book
  status and information, *Go to ▸* (go to page, skim, book map, page
  browser, back/forward); **Search** = dictionary, vocabulary, translate
  page, learning languages, Wikipedia, full-text and bookmark search;
  **Settings** = status bar, page turns, scrolling, long-press, links,
  autoturn, non-linear flows, reading statistics, export, read timer,
  *Settings…* (the Settings app). Everything else (network,
  screen, gestures, device, file browser, History, collections, My Kobo,
  Tools, USB, update, help) is still built into the menu as the submenu
  `kobo_everything`, but mykobo takes it out of sight once the menu is built
  (`menu.kobo_hidden`), where the Settings app finds its items. The file browser's menu is
  unchanged.
- **Quick menu** (hold the top-left corner, set by mykobo): light, night
  mode, side-by-side translation, learning mode, bookmark, orientation.
  The first list (until 2026-11-06) is replaced once if it was never
  changed (`kobo_quick_menu_v`).
- **Auto-rotate** (Settings › Screen in the Settings app): the Kobo
  apps follow the accelerometer's turn through `DeviceMenu.followRotation`
  (KOReader sends it only to the window in front); Chess and Solitaire
  only between upright and upside down.
- **History** has the apps' title bar (`standard_title_bar` in BookList:
  the X the size of Chess's); its X goes Home, and a swipe down from the
  top opens the device menu (stock: it closed History).
- **Progress sync never makes you wait** (`plugins/kosync.koplugin`):
  stock auto sync turns Wi-Fi on and waits for it on every wake, sleep
  and book close (over a minute with no network in reach). Now waking
  starts Wi-Fi in the background and pulls when it connects; sleep and
  closing a book push only when already online.
- **File browser**: folders are a strip of labelled buttons under the
  title bar (`filemanagerfolderstrip.lua`; by name, 3 rows, then "N
  more"), books alone fill the grid; no "../" tile, a ⌃ button beside
  the House instead (TitleBar `left2_icon`, `setBottomWidget`); the
  Kobo's `fonts` folder is hidden. *My Kobo › Move loose books into
  Books* moves the books at the top of home into `Books/` (sidecars,
  history, collections) and points downloads there; it only runs when
  asked (it ran by itself once until 2026-11-06).
- **Rounded buttons everywhere** (`frontend/ui/widget/button.lua`,
  `virtualkeyboard.lua`): every button with a frame has rounded corners, in
  the Launcher's own screens and in every app, without the apps doing
  anything (a caller that wants square corners passes `radius = 0`); the
  keys of the on-screen keyboard too. The tap highlight no longer uses the
  radius' value to know it was the one that rounded the button.
- **PDFs open in page view** (`koptoptions.lua`, stock: continuous, where
  every page turn starts lower on the page).

Third-party plugins on the Kobo: **Solitaire**,
github.com/Lalocaballero/solitaire.koplugin (MIT; installed at commit
9f95960, 2026-10-14), listed in My Kobo, with
`solitaire-sizes.patch` applied (`patch -p1` in the plugin
folder): on the Elipsa the status line was cut off and the rank
and suit symbols too big; now the status line fits the bar and the
screen width, and the symbols are about half their old size.
Then `solitaire-kobo.patch` (after the sizes patch): laid out like
KoboChess (title bar with an X to quit, a bold status line, one row of
framed buttons: Game ▾, Undo, Hint, Auto, Refresh, Options ▾); double tap
a top card to send it to its suit's pile (an Ace, or the next of a started
suit); a swipe down from the top opens the device menu; and the game
window is no longer modal, so the menu and its dialogs can go above it.
Then `solitaire-help.patch` (after the Kobo patch): every button and menu
item explains itself the first time it is used, in a dialog with a *Do not
show this again* box (new files `solitairehelpdialog.lua`,
`solitairehelptext.lua`; the choice is kept in `solitaire_settings.lua`),
and *Show explanations again* in the device menu brings them all back.
`kobo/install-solitaire.sh KOBO_IP` assembles the patched plugin (KoboHub's
vendored copy + the three patches in order, as KoboKit's build-kit does)
and copies it to the Kobo over KOReader's SSH server. MenuSorter now puts a plugin
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

## Issues

Please open issues on [KoboKit](https://github.com/mlongval/KoboKit/issues) using its forms, and read
[how issues work](https://github.com/mlongval/KoboKit/blob/main/CONTRIBUTING.md) first. Fixes are made by
Claude Code, so only clearly described, reproducible problems and concrete
change requests are accepted.

## Thanks

This is a fork of [KOReader](https://github.com/koreader/koreader). **A big
thank you to the KOReader team** and all its contributors: everything here
is a small layer on their work. Please don't report problems with this fork
to the KOReader project. They come from these changes, not from KOReader.
The changes are under KOReader's licence (AGPL-3.0, see `COPYING`), with no
warranty.
