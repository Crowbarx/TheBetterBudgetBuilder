-- The BBB in your bags:
--  * EllesmereUI bags: a "Budget" row in the bag sidebar (under Keyring and
--    your categories). Picking it shows Safe to spend, your buckets and any
--    loans in the item area.
--  * "Safe to spend" beside your gold in the bag footer (EllesmereUI or Blizzard bags).
-- Nothing in EllesmereUI is edited; this hooks in at runtime, the same way
-- Bag Keyring does (EUIBagRows.lua is shared with it).
local _, ns = ...
local T, Bk = ns.T, ns.BucketMath
local R = _G.EUIBagExtraRows

local ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local E = {}
local function Bags() return _G.EUI_Bags end
local function Active() return R and R:IsActive("bbb") end

---------------------------------------------------------------------------
-- The bag view
---------------------------------------------------------------------------
local function BuildOverlay()
  local bags = Bags()
  local o = CreateFrame("Frame", nil, bags)
  o:SetFrameLevel(bags:GetFrameLevel() + 100)
  o:EnableMouse(true)
  o:EnableMouseWheel(true)
  T.Fill(o, "BACKGROUND", 0.055, 0.055, 0.055, 0.98):SetAllPoints()
  local sf = CreateFrame("ScrollFrame", nil, o)
  sf:SetPoint("TOPLEFT", 10, -10); sf:SetPoint("BOTTOMRIGHT", -10, 10)
  local c = CreateFrame("Frame", nil, sf)
  c:SetSize(10, 10)
  sf:SetScrollChild(c)
  sf:SetScript("OnSizeChanged", function(_, w) c:SetWidth(w) end)
  o:SetScript("OnMouseWheel", function(_, delta)
    local max = math.max(0, c:GetHeight() - sf:GetHeight())
    sf:SetVerticalScroll(math.max(0, math.min(max, sf:GetVerticalScroll() - delta * 40)))
  end)
  o.sf, o.c = sf, c

  o.safeLabel = T.Bold(c, 10, T.MUTED, "SAFE TO SPEND"); o.safeLabel:SetPoint("TOPLEFT", 2, -4)
  o.safe = T.Bold(c, 18, T.TEXT); o.safe:SetPoint("TOPLEFT", o.safeLabel, "BOTTOMLEFT", 0, -6)
  o.split = T.Med(c, 10, T.MUTED); o.split:SetPoint("TOPLEFT", o.safe, "BOTTOMLEFT", 0, -6); o.split:SetPoint("RIGHT", c, "RIGHT")
  o.open = T.Button(c, "Open the BBB", 120, 24, function() ns.ToggleWindow("overview") end)
  o.open:SetPoint("TOPRIGHT", 0, -4)
  o.head = T.Section(c, "Buckets")
  o.rows = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(46)
    r.icon = T.Icon(r, 24); r.icon:SetPoint("TOPLEFT", 10, -9)
    r.name = T.Bold(r, 12); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
    r.value = T.Bold(r, 11); r.value:SetPoint("TOPRIGHT", -10, -9); r.value:SetJustifyH("RIGHT")
    r.name:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
    r.bar = T.Bar(r, 3)
    r.bar.track:SetPoint("BOTTOMLEFT", 42, 9); r.bar.track:SetPoint("BOTTOMRIGHT", -10, 9)
    return r
  end)
  o.loanHead = T.Section(c, "Loans")
  o.loans = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(30)
    r.name = T.Bold(r, 12); r.name:SetPoint("LEFT", 10, 0)
    r.value = T.Bold(r, 11, T.BAD); r.value:SetPoint("RIGHT", -10, 0)
    return r
  end)
  o.fill = T.Button(c, "Fill to goals", 120, 24, function()
    local moved = Bk.FillAll(ns.Buckets(), math.max(0, ns.Safe()), ns.Goal)
    ns.Print(moved > 0 and ("Moved " .. ns.Fmt(moved, true) .. " into your buckets.") or "Nothing to move.")
    ns.Changed()
  end)
  o:Hide()
  E.overlay = o
end

local function RefreshOverlay()
  local o = E.overlay
  if not o or not o:IsShown() then return end
  local c = o.c
  local safe = ns.Safe()
  o.safe:SetText(ns.Coins(safe, 16))
  local col = safe < 0 and T.BAD or T.TEXT
  o.safe:SetTextColor(col[1], col[2], col[3])
  local owed = ns.Owed()
  o.split:SetText(("Gold %s   ·   in buckets %s%s"):format(ns.Fmt(ns.Gold()), ns.Fmt(Bk.Saved(ns.Buckets())),
    owed > 0 and ("   ·   owed " .. ns.Fmt(owed)) or ""))
  local y = 84
  o.head:ClearAllPoints(); o.head:SetPoint("TOPLEFT", 0, -y); o.head:SetPoint("RIGHT", c, "RIGHT")
  y = y + 26
  o.rows:Reset()
  for _, b in ipairs(ns.Buckets()) do
    local r = o.rows:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.icon:SetTexture(b.icon)
    r.name:SetText(b.name)
    local goal = ns.Goal(b)
    r.value:SetText(ns.Coins(b.saved, 11) .. (goal and ("  |cff9a9aa0/ " .. ns.Fmt(goal) .. "|r") or ""))
    r.bar:Set(goal and goal > 0 and b.saved / goal or 0, goal and b.saved >= goal and T.GOOD or nil)
    r.tip = function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(b.name, 1, 1, 1)
      GameTooltip:AddDoubleLine("Saved", ns.Fmt(b.saved, true), 0.8, 0.8, 0.8)
      if goal then GameTooltip:AddDoubleLine("Goal", ns.Fmt(goal, true), 0.8, 0.8, 0.8) end
      GameTooltip:AddDoubleLine("Auto-fill", (b.pct or 0) .. "%", 0.8, 0.8, 0.8, 1, 1, 1)
      GameTooltip:Show()
    end
    y = y + 50
  end
  o.fill:ClearAllPoints(); o.fill:SetPoint("TOPLEFT", 0, -(y + 2))
  y = y + 38
  local list = ns.OpenLoans()
  for _, l in ipairs((ns.OpenLoans("out"))) do list[#list + 1] = l end
  o.loanHead:SetShown(#list > 0)
  o.loans:Reset()
  if #list > 0 then
    o.loanHead:ClearAllPoints(); o.loanHead:SetPoint("TOPLEFT", 0, -y); o.loanHead:SetPoint("RIGHT", c, "RIGHT")
    y = y + 26
    for _, l in ipairs(list) do
      local r = o.loans:Get(c)
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
      r.name:SetText(l.name)
      local out = ns.LoanDir(l) == "out"
      local col = out and T.GOOD or T.BAD
      r.value:SetTextColor(col[1], col[2], col[3])
      r.value:SetText((out and "+" or "-") .. ns.Coins(ns.Remaining(l), 11))
      y = y + 34
    end
  end
  c:SetHeight(y + 10)
  T.Repaint()
end

local function PlaceOverlay()
  local bags, o = Bags(), E.overlay
  o:ClearAllPoints()
  if bags._scrollFrame then o:SetPoint("TOPLEFT", bags._scrollFrame, "TOPLEFT", 0, 0)
  else o:SetPoint("TOPLEFT", bags, "TOPLEFT", (bags._sidebar and bags._sidebar:GetWidth() or 0), -36) end
  if bags.Footer then o:SetPoint("BOTTOMRIGHT", bags.Footer, "TOPRIGHT", 0, 0)
  else o:SetPoint("BOTTOMRIGHT", bags, "BOTTOMRIGHT", 0, 30) end
end

local function ShowOverlay()
  if not E.overlay then BuildOverlay() end
  PlaceOverlay()
  E.overlay:Show()
  RefreshOverlay()
end
local function HideOverlay() if E.overlay then E.overlay:Hide() end end

local function PaintCount(b)
  local safe = ns.Safe()
  b._count:SetText(ns.Fmt(math.floor(math.max(0, safe) / 10000) * 10000))
  b._count:SetTextColor(safe < 0 and 1 or 0.5, safe < 0 and 0.42 or 0.5, safe < 0 and 0.42 or 0.5)
end

local row = {
  id = "bbb",
  order = 30,
  make = function(child, refLabel)
    local b = R.MakeRow(child, refLabel, "BBBSidebarButton", "Budget", ICON)
    b._rowId = "bbb"
    b:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("Budget", 1, 1, 1)
      GameTooltip:AddDoubleLine("Safe to spend", ns.Fmt(ns.Safe(), true), 0.85, 0.85, 0.85)
      for _, bk in ipairs(ns.Buckets()) do GameTooltip:AddDoubleLine(bk.name, ns.Fmt(bk.saved, true), 0.7, 0.7, 0.7) end
      GameTooltip:Show()
    end)
    b:SetScript("OnClick", function() ns.SetBagView(not Active()) end)
    E.btn = b
    return b
  end,
  paint = function(b, active)
    R.PaintRow(b, active)
    PaintCount(b)
    if active then ShowOverlay() else HideOverlay() end
  end,
  onLeave = HideOverlay,
}

local function AfterRefresh()
  local bags = Bags()
  if not bags or not bags:IsVisible() then return end
  R:Hook()
  if Active() then ShowOverlay(); R:DimTheirs() else HideOverlay() end
  if E.btn then R.PaintRow(E.btn, Active()); PaintCount(E.btn) end
end

function ns.SetBagView(on)
  if not Bags() or not R then return end
  if on then R:Activate("bbb") elseif Active() then R:Activate(nil) end
end

local function HookEllesmere()
  local bags = Bags()
  if not bags or E.ready or not R or not ns.db.settings.bagRow then return end
  if type(bags.RefreshInventory) ~= "function" then return end
  E.ready = true
  R:Register(row)
  hooksecurefunc(bags, "RefreshInventory", AfterRefresh)
  bags:HookScript("OnShow", function() C_Timer.After(0, AfterRefresh) end)
  R:Hook()
  if bags:IsShown() then AfterRefresh() end
end

---------------------------------------------------------------------------
-- Safe to spend beside your gold
---------------------------------------------------------------------------
local foot = {}

local function MoneyFrame(bag)
  return bag.Money or bag.MoneyFrame or _G[(bag:GetName() or "") .. "MoneyFrame"]
end

-- Hide (or bring back) the bag's own gold so only Safe to spend shows. The
-- frame stays in place, just invisible and unclickable, so nothing else moves.
local function ShowBagGold(mf, shown)
  if not mf or not mf.SetAlpha then return end
  mf:SetAlpha(shown and 1 or 0)
  local name = mf.GetName and mf:GetName()
  for _, part in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
    local b = name and _G[name .. part]
    if b and b.EnableMouse then b:EnableMouse(shown) end
  end
  if mf.EnableMouse then mf:EnableMouse(shown) end
end

local function MoneyAnchor(bag)
  local mf = MoneyFrame(bag)
  if mf and mf.GetName and mf:GetName() then
    for _, part in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
      local b = _G[mf:GetName() .. part]
      if b and b:IsShown() then return b end
    end
  end
  return mf
end

local function PlaceFoot(bag)
  local f = foot[bag]
  if not f then
    f = CreateFrame("Button", nil, bag)
    f:SetFrameLevel(bag:GetFrameLevel() + 20)
    f.value = T.Bold(f, 11, T.TEXT)
    f.value:SetPoint("RIGHT")
    f.label = T.Med(f, 9, T.MUTED, "Safe to spend")
    f.label:SetPoint("RIGHT", f.value, "LEFT", -5, 0)
    f:SetScript("OnClick", function()
      if bag == Bags() and E.ready then ns.SetBagView(not Active()) else ns.ToggleWindow("overview") end
    end)
    f:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Safe to spend", 1, 1, 1)
      GameTooltip:AddDoubleLine("Your gold", ns.Coins(ns.Gold()), 0.8, 0.8, 0.8, 1, 1, 1)
      GameTooltip:AddDoubleLine("In buckets", "-" .. ns.Coins(Bk.Saved(ns.Buckets())), 0.8, 0.8, 0.8, 1, 1, 1)
      local owed = ns.Owed()
      if owed > 0 then GameTooltip:AddDoubleLine("Owed to friends", "-" .. ns.Coins(owed), 0.8, 0.8, 0.8, 1, 0.42, 0.42) end
      GameTooltip:AddDoubleLine("Safe to spend", ns.Coins(ns.Safe()), 1, 1, 1, 1, 1, 1)
      local toMe = ns.OwedToMe()
      if toMe > 0 then GameTooltip:AddDoubleLine("Friends owe you", "+" .. ns.Coins(toMe), 0.8, 0.8, 0.8, 0.42, 0.85, 0.6) end
      GameTooltip:AddLine("Click for your budget", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    foot[bag] = f
  end
  local mf = MoneyFrame(bag)
  local hideGold = ns.db.settings.bagFooter and ns.db.settings.hideBagGold
  ShowBagGold(mf, not hideGold)
  if not ns.db.settings.bagFooter then f:Hide(); return end
  local safe = ns.Safe()
  f.value:SetText(ns.Coins(safe, 12))
  local col = safe < 0 and T.BAD or T.GOOD
  f.value:SetTextColor(col[1], col[2], col[3])
  f:SetSize(f.value:GetStringWidth() + f.label:GetStringWidth() + 10, 16)
  f:ClearAllPoints()
  local a = MoneyAnchor(bag)
  if hideGold and mf then f:SetPoint("RIGHT", mf, "RIGHT", 0, 0)
  elseif a then f:SetPoint("RIGHT", a, "LEFT", -14, 0) else f:SetPoint("BOTTOMLEFT", bag, "BOTTOMLEFT", 12, 8) end
  f:Show()
end

local BAG_FRAMES = { "EUI_Bags", "ContainerFrameCombinedBags", "ContainerFrame1" }
local function RefreshFoot()
  for _, n in ipairs(BAG_FRAMES) do
    local f = _G[n]
    if f and f:IsShown() then PlaceFoot(f) end
  end
end

---------------------------------------------------------------------------
-- Glue
---------------------------------------------------------------------------
ns.OnChange(function()
  RefreshOverlay()
  if E.btn then PaintCount(E.btn) end
  RefreshFoot()
end)

local hookedBags = {}
local function OnBagsOpened()
  HookEllesmere()
  for _, n in ipairs(BAG_FRAMES) do
    local f = _G[n]
    if f and not hookedBags[f] then
      hookedBags[f] = true
      f:HookScript("OnShow", function() C_Timer.After(0.05, RefreshFoot) end)
    end
  end
  C_Timer.After(0.1, RefreshFoot)
end

for _, fn in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack" }) do
  if _G[fn] then hooksecurefunc(fn, OnBagsOpened) end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
  OnBagsOpened()
  C_Timer.After(3, OnBagsOpened)
end)
