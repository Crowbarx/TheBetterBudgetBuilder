-- The BBB (Better Budget Builder): saved data, settings and shared helpers.
-- Everything is stored account-wide in BBBDB so alts can join one budget later.
local ADDON, ns = ...
_G.BBB = ns
ns.ADDON = ADDON
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"

local M, P, Lines, Bk, Tr = ns.Money, ns.Period, ns.Lines, ns.BucketMath, ns.Training

local TAG = "|cffe3ab70BBB|r: "
function ns.Print(msg) print(TAG .. msg) end
ns.Fmt = M.Format
ns.Coins = M.Icons

---------------------------------------------------------------------------
-- Change notifications (one per action, never on a timer)
---------------------------------------------------------------------------
local listeners = {}
function ns.OnChange(fn) listeners[#listeners + 1] = fn end
function ns.Changed()
  for _, fn in ipairs(listeners) do
    local ok, err = pcall(fn)
    if not ok and ns.debug then ns.Print("|cffff6060" .. tostring(err) .. "|r") end
  end
end

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
local SETTINGS = {
  theme = "classcolor",        -- classcolor | midnight | dark | wallpaper (your own AddOns\\BBB_Wallpaper\\Wallpaper.tga)
  artShade = 0.72,             -- how dark the shade over the wallpaper is
  classAccent = true,
  accent = { 0.89, 0.67, 0.44, 1 },
  contentScale = 0.8,
  guard = true,                -- ask before a purchase dips into a bucket
  includeAlts = false,         -- count every character's gold (one master budget)
  bagRow = true,               -- "Budget" row in the EllesmereUI bag sidebar
  bagFooter = true,            -- Safe to spend beside your gold
  hideBagGold = true,          -- hide the bag's own gold total, show only Safe to spend
  loanPrompts = true,          -- ask to log loans on trades and mail
  minimap = {},
  minimapShown = true,
  chartGroup = "day",
  chartCount = 14,
}

local function DefaultBuckets()
  return {
    { id = "training", name = "Training", icon = "Interface\\Icons\\INV_Misc_Book_11", saved = 0, pct = 25, auto = "training" },
    { id = "mount", name = "Epic Mount", icon = "Interface\\Icons\\Ability_Mount_Raptor", saved = 0, pct = 25,
      target = 10000000, dueLevel = 60 },
  }
end

local function Fill(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then
      if type(v) == "table" then local c = {}; for a, b in pairs(v) do c[a] = b end; t[k] = c else t[k] = v end
    end
  end
end

function ns.InitDB()
  BBBDB = BBBDB or {}
  local db = BBBDB
  db.version = db.version or 1
  db.settings = db.settings or {}
  Fill(db.settings, SETTINGS)
  db.chars = db.chars or {}
  db.ledger = db.ledger or {}
  db.seq = db.seq or 0
  db.buckets = db.buckets or DefaultBuckets()
  db.categories = db.categories or Lines.DefaultCategories()
  db.rules = db.rules or {}
  db.loans = db.loans or {}
  -- 1.0.2: fast auto-loot paid out before the loot window opened, so mob gold
  -- landed in "Other income"; move those early rows to Loot once.
  if db.settings.theme == "firefly" then db.settings.theme = "wallpaper" end -- 1.0.6 rename
  if not db.fixedLoot then
    for _, r in ipairs(db.ledger) do if r.src == "other_in" then r.src = "loot" end end
    db.fixedLoot = true
  end
  ns.db = db
  return db
end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------
function ns.CharKey()
  return (GetRealmName() or "?") .. "-" .. (UnitName("player") or "?")
end

function ns.Char(key)
  key = key or ns.CharKey()
  local c = ns.db.chars[key]
  if not c then
    c = { levels = {}, played = {} }
    ns.db.chars[key] = c
  end
  return c
end

-- Your characters' names (short, lowercase) for spotting transfers.
function ns.IsMine(name)
  if not name or name == "" then return false end
  local short = (name:match("^([^%-]+)") or name):lower()
  for key in pairs(ns.db.chars) do
    local n = key:match("%-([^%-]+)$")
    if n and n:lower() == short then return true end
  end
  return false
end

---------------------------------------------------------------------------
-- Days
---------------------------------------------------------------------------
function ns.Today() return P.DayOfTable(date("*t")) end
function ns.DayOf(t) return P.DayOfTable(date("*t", t)) end

---------------------------------------------------------------------------
-- Gold, buckets, loans
---------------------------------------------------------------------------
function ns.Gold()
  if ns.db.settings.includeAlts then
    local me, total = ns.CharKey(), GetMoney()
    for key, c in pairs(ns.db.chars) do
      if key ~= me then total = total + (c.money or 0) end
    end
    return total
  end
  return GetMoney()
end

function ns.Buckets() return ns.db.buckets end

function ns.Bucket(id)
  for _, b in ipairs(ns.db.buckets) do if b.id == id then return b end end
end

-- Your level, even in the moment before UnitLevel catches up after a ding.
function ns.Level()
  local c = ns.db and ns.Char()
  return math.max(UnitLevel("player") or 1, c and c.level or 1)
end

function ns.TrainingSpells()
  local t = ns.Char().trainer
  return t and t.spells
end

-- A bucket's goal in copper (nil = no goal).
function ns.Goal(b)
  if b.auto == "training" then
    return Tr.Goal(ns.TrainingSpells(), ns.Level())
  end
  if b.target and b.target > 0 then return b.target end
  return nil
end

function ns.Owed()
  local t = 0
  for _, l in ipairs(ns.db.loans) do
    if (l.dir or "in") == "in" then t = t + math.max(0, (l.amount or 0) - (l.paid or 0)) end
  end
  return t
end

function ns.Safe()
  return Bk.Safe(ns.Gold(), ns.db.buckets, ns.Owed())
end

---------------------------------------------------------------------------
-- Categories and lines
---------------------------------------------------------------------------
function ns.Cats() return ns.db.categories end

function ns.Cat(id)
  for _, c in ipairs(ns.db.categories) do if c.id == id then return c end end
end

function ns.LineOf(row)
  return Lines.LineFor(row, ns.db.rules, ns.db.categories)
end

function ns.LineLabel(line)
  if not line then return "?" end
  if line == "transfer" then return "Transfer" end
  local src = line:match("^income:(.+)$")
  if src then return (Lines.SOURCES[src] and Lines.SOURCES[src].label) or src end
  local id = line:match("^cat:(.+)$")
  local c = id and ns.Cat(id)
  if c then
    local p = c.parent and ns.Cat(c.parent)
    return p and (p.name .. " › " .. c.name) or c.name
  end
  return line
end

function ns.SourceLabel(src)
  return (Lines.SOURCES[src] and Lines.SOURCES[src].label) or src or "?"
end

---------------------------------------------------------------------------
-- Popups
---------------------------------------------------------------------------
StaticPopupDialogs["BBB_CONFIRM"] = {
  text = "%s", button1 = YES, button2 = NO,
  OnAccept = function(self, data) data = data or self.data; if data and data.yes then data.yes() end end,
  OnCancel = function(self, data) data = data or self.data; if data and data.no then data.no() end end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3, showAlert = true,
}
function ns.Confirm(text, yes, no, yesText, noText)
  local d = StaticPopupDialogs["BBB_CONFIRM"]
  d.button1, d.button2 = yesText or YES, noText or NO
  local data = { yes = yes, no = no }
  local dlg = StaticPopup_Show("BBB_CONFIRM", text, nil, data)
  if dlg then dlg.data = data end
end

StaticPopupDialogs["BBB_INPUT"] = {
  text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true,
  OnShow = function(self, data)
    data = data or self.data
    local eb = self.editBox or self.EditBox
    eb:SetText(data and data.default or ""); eb:HighlightText(); eb:SetFocus()
  end,
  OnAccept = function(self, data)
    data = data or self.data
    local eb = self.editBox or self.EditBox
    if data and data.fn then data.fn(eb:GetText()) end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    StaticPopupDialogs["BBB_INPUT"].OnAccept(parent, parent.data)
    parent:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
function ns.Ask(text, default, fn)
  local data = { default = default, fn = fn }
  local dlg = StaticPopup_Show("BBB_INPUT", text, nil, data)
  if dlg then dlg.data = data end
end

function ns.AskMoney(text, default, fn)
  ns.Ask(text, default, function(t)
    local v = M.Parse(t)
    if v then fn(v) else ns.Print("Couldn't read that amount. Try 5, 2g 50s or 75s.") end
  end)
end

---------------------------------------------------------------------------
-- Rows and play time for the views (this character, or all with alts on)
---------------------------------------------------------------------------
function ns.Rows()
  if ns.db.settings.includeAlts then return ns.db.ledger end
  local me, out = ns.CharKey(), {}
  for _, r in ipairs(ns.db.ledger) do if r.char == me then out[#out + 1] = r end end
  return out
end

function ns.Played(fromDay)
  local total = 0
  local me = ns.CharKey()
  for key, c in pairs(ns.db.chars) do
    if ns.db.settings.includeAlts or key == me then
      for day, sec in pairs(c.played or {}) do if day >= fromDay then total = total + sec end end
    end
  end
  return total
end

function ns.Unsorted()
  local n = 0
  for _, r in ipairs(ns.Rows()) do
    if ns.Lines.Kind(r) == "spend" and ns.Lines.IsUnsorted(ns.LineOf(r)) and not r.line then n = n + 1 end
  end
  return n
end
