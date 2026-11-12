# Changelog

## 1.0.14
- Training: an "All to 60" card with the cost of every spell you still need (skipped ones left out), and the footer shows what you skipped.
- Training: "+ Goal" and "- Goal" on each level let you pre-save for later levels, or take your next level out of the Training goal. Ready spells always count.

## 1.0.13
- Spending and Income have a Day tab: one day at a time as a ring chart with a legend, plus that day's totals. Use < and > to step through days, or Today to jump back.
- The version under the sidebar no longer shows "vv".

## 1.0.12
- The Train my list bar sizes itself to its text, so the skip note no longer runs under the button.

## 1.0.11
- Wallpaper: "Shuffle all" shows a different one of your pictures each time you open the BBB, like a Wallpaper Engine playlist.

## 1.0.10
- Fixed buckets filling with more gold than you have. Forever can report 0 gold at logout and for a moment at login, which made your whole wallet look like new income and auto-fill put it in your buckets again. The BBB now waits for your real gold, and keeps the last gold it saw when logging out.
- Auto-fill only uses gold you earn while playing, never a login gap, and never fills buckets past the gold you have.
- At login, if your buckets hold more than your gold, the extra goes back to Safe to spend (bottom bucket first).
- Settings: the Accent color and Wallpaper descriptions no longer run into their buttons.
- The close button draws its X from lines, so it no longer shows up as an empty box.

## 1.0.9
- Wallpaper theme: keep several pictures and pick one in Settings → Wallpaper. List them in `BBB_Wallpaper\List.lua` (see the README).
- Accent color: pick one of nine colors, or any color from the color wheel, when Class color accent is off.
- Window scale: Auto fits the window to your screen and UI scale, and it never grows past your screen. Set it by hand with - and +, or `/bbb scale 50`–`150`. `/bbb reset` centers the window and goes back to Auto.

## 1.0.8
- The Wallpaper theme now loads from `Interface\AddOns\BBB_Wallpaper\Wallpaper.tga`, outside the addon folder, so updates don't delete your picture.

## 1.0.7
- Shorter Settings and Overview text, so nothing gets cut off.

## 1.0.6
- First public version. Works as a plugin for EllesmereUI bags (a Budget sidebar row and Safe to spend in the footer), or on its own.
  The Wallpaper theme now uses your own `Media/Wallpaper.tga`, and Class colored is the default theme.
- Train my list buys ready spells, except skipped ones, at your class trainer.
- Loans both ways: gold you owe and gold owed to you.
- The bag footer can hide your total gold and show only Safe to spend.
- Loot and quest gold are labeled correctly with fast auto-loot.
- Forever trainer data is read correctly.
- New icon picker and minimap icon.
