-- Sources and categories. Every ledger row has a source (what caused the gold
-- change). Spending rows resolve to a category ("cat:<id>"), income rows to
-- "income:<source>", and moves between your own characters to "transfer".
-- WoW-free (unit tested in tests/).
local _, ns = ...
local L = {}
ns.Lines = L

-- kind: "spend", "income", "transfer" or "either" (the sign decides)
L.SOURCES = {
  repair       = { label = "Repairs",             kind = "spend",  default = "cat:repairs" },
  training     = { label = "Class training",      kind = "spend",  default = "cat:training" },
  profession   = { label = "Profession training", kind = "spend",  default = "cat:professions" },
  flight       = { label = "Flight",              kind = "spend",  default = "cat:travel" },
  vendor_buy   = { label = "Vendor purchase",     kind = "spend",  default = "cat:vendor" },
  buyback      = { label = "Buyback",             kind = "spend",  default = "cat:vendor" },
  ah_buy       = { label = "AH purchase",         kind = "spend",  default = "cat:ahbuys" },
  ah_fee       = { label = "AH deposit",          kind = "spend",  default = "cat:ahfees" },
  postage      = { label = "Postage",             kind = "spend",  default = "cat:postage" },
  mail_gift    = { label = "Gold mailed",         kind = "spend",  default = "cat:other" },
  trade_out    = { label = "Traded away",         kind = "spend",  default = "cat:other" },
  loan_repay   = { label = "Loan repayment",      kind = "spend",  default = "cat:loans" },
  other        = { label = "Other",               kind = "spend",  default = "cat:other" },
  loot         = { label = "Loot",                kind = "income" },
  quest        = { label = "Quest rewards",       kind = "income" },
  vendor_sell  = { label = "Vendor sales",        kind = "income" },
  ah_sale      = { label = "AH sales",            kind = "income" },
  ah_refund    = { label = "AH refunds",          kind = "income" },
  mail_in      = { label = "Mail",                kind = "income" },
  trade_in     = { label = "Trades",              kind = "income" },
  loan_in      = { label = "Loans received",      kind = "income" },
  other_in     = { label = "Other income",        kind = "income" },
  loan_out     = { label = "Lent to a friend",    kind = "transfer" },
  loan_back    = { label = "Friend paid you back", kind = "transfer" },
  transfer_out = { label = "To your character",   kind = "transfer" },
  transfer_in  = { label = "From your character", kind = "transfer" },
  unexplained  = { label = "Unexplained",         kind = "either", default = "cat:other" },
}

-- The order income sources are listed in.
L.INCOME_ORDER = { "loot", "quest", "vendor_sell", "ah_sale", "ah_refund", "mail_in", "trade_in", "loan_in", "other_in", "unexplained" }

-- Starter spending categories. `bucket` = the savings bucket that pays for it
-- (training comes out of the Training bucket). `match` = item subtype words
-- that sort a consumable into a sub-category.
function L.DefaultCategories()
  return {
    { id = "repairs",     name = "Repairs" },
    { id = "training",    name = "Class training", bucket = "training" },
    { id = "consumables", name = "Consumables" },
    { id = "food",        name = "Food & drink", parent = "consumables", match = "food" },
    { id = "potions",     name = "Potions",      parent = "consumables", match = "potion" },
    { id = "elixirs",     name = "Elixirs",      parent = "consumables", match = "elixir" },
    { id = "bandages",    name = "Bandages",     parent = "consumables", match = "bandage" },
    { id = "reagents",    name = "Reagents" },
    { id = "travel",      name = "Travel" },
    { id = "vendor",      name = "Vendor purchases" },
    { id = "ahbuys",      name = "AH purchases" },
    { id = "ahfees",      name = "AH fees" },
    { id = "postage",     name = "Postage" },
    { id = "professions", name = "Professions" },
    { id = "loans",       name = "Loan repayments" },
    { id = "other",       name = "Other" },
  }
end

-- Item class ids (Enum.ItemClass): 0 Consumable, 5 Reagent.
local CONSUMABLE, REAGENT = 0, 5

function L.Kind(row)
  local s = L.SOURCES[row.src]
  local k = s and s.kind or ((row.d or 0) < 0 and "spend" or "income")
  if k == "either" then k = (row.d or 0) < 0 and "spend" or "income" end
  return k
end

-- The line a row belongs to. Order: the row's own pick > item rule > NPC rule >
-- source rule > the item's class (consumables, reagents) > the source default.
-- rules: { ["item:123"] = "cat:food", ["npc:Name"] = "cat:x", ["src:ah_buy"] = ... }
-- cats: the category list; a rule or pick naming a deleted category is ignored.
function L.LineFor(row, rules, cats)
  local kind = L.Kind(row)
  if kind == "transfer" then return "transfer" end
  if kind == "income" then return "income:" .. (row.src or "other_in") end
  local known = {}
  for _, c in ipairs(cats or {}) do known["cat:" .. c.id] = c end
  local function ok(key) return key and known[key] and key or nil end
  local pick = ok(row.line)
  if pick then return pick end
  rules = rules or {}
  local r = (row.item and ok(rules["item:" .. row.item])) or (row.who and ok(rules["npc:" .. row.who]))
    or ok(rules["src:" .. (row.src or "")])
  if r then return r end
  if row.src == "vendor_buy" or row.src == "ah_buy" or row.src == "buyback" then
    if row.ic == CONSUMABLE then
      local sub = (row.isub or ""):lower()
      for _, c in ipairs(cats or {}) do
        if c.match and c.parent == "consumables" and sub:find(c.match, 1, true) then return "cat:" .. c.id end
      end
      if ok("cat:consumables") then return "cat:consumables" end
    elseif row.ic == REAGENT and ok("cat:reagents") then
      return "cat:reagents"
    end
  end
  local s = L.SOURCES[row.src]
  return ok(s and s.default) or "cat:other"
end

-- A category's top-level parent id ("food" -> "consumables").
function L.TopOf(catId, cats)
  for _, c in ipairs(cats or {}) do
    if c.id == catId then return c.parent or c.id end
  end
  return catId
end

-- The bucket that pays for a line, if any (follows the parent).
function L.BucketFor(line, cats)
  local id = line and line:match("^cat:(.+)$")
  if not id then return nil end
  local byId = {}
  for _, c in ipairs(cats or {}) do byId[c.id] = c end
  local c = byId[id]
  if not c then return nil end
  if c.bucket then return c.bucket end
  local p = c.parent and byId[c.parent]
  return p and p.bucket or nil
end

-- "Other" counts as unsorted: it should stay small and easy to clear.
function L.IsUnsorted(line) return line == "cat:other" end

return L
