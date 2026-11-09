# The BBB (Better Budget Builder)

A gold budget for WoW Classic Forever. It tracks every copper you earn and spend, sorts gold into savings buckets, and asks before a purchase dips into them.

## What it does

- **Safe to spend:** your gold minus what's in buckets and what you owe. It shows in the sidebar, on the minimap button, and in the EllesmereUI bag footer, which can hide your total gold.
- **Buckets:** named savings piles with goals, goal levels, auto-fill percentages and icons. Training and Epic Mount (1,000g by 60) come built in.
- **Vendor guard:** a popup before a buy dips into a bucket.
- **Training:** read from your class trainer. Spells are grouped by level with real prices, and you can skip spells you won't train. The Training bucket's goal follows your level. **Train my list** buys everything that's ready except what you skipped.
- **Loans, both ways:** gold friends lent you and gold you lent them. Trades and mail ask whether they were loans.
- **Ledger, Spending and Income:** every gold change, categories with sorting rules, and charts by day, week or month.
- **EllesmereUI bags:** a Budget row in the bag sidebar.

Open it with `/bbb`, the minimap button or the Budget row in your bags. `/bbb help` lists the commands.

## Wallpaper theme

The Wallpaper theme uses your own picture. Save it as `Media/Wallpaper.tga`: a 2048×1024 TGA with the image in the left 1521 px (the window's shape). Then restart the game and pick Settings → Theme → Wallpaper. You can adjust the shade over it in Settings.

## Development

`tests/logic_test.lua` covers the WoW-free logic in `Logic/`. Run it with LuaJIT from the addon folder:

```
luajit tests/logic_test.lua
```

Releases are made by pushing a `v*` tag. The GitHub Action packages the addon with the BigWigs packager. It uploads to CurseForge once the `CF_API_KEY` secret and `## X-Curse-Project-ID` are set.

Fonts: Montserrat (SIL Open Font License, see `Media/Montserrat-OFL.txt`).
