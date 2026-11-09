-- Reads your class trainer: every spell, its level and its real price
-- (reputation discounts included). Runs only when you open the trainer.
local _, ns = ...
local Tr = ns.Training

local FILTERS = { "available", "unavailable", "used" }

local KINDS = { available = true, unavailable = true, used = true, header = true }

-- Classic returns (name, rank, kind); Forever returns (name, kind, icon, ...).
-- Read whichever order this client uses.
local function ReadService(i)
  local v = { GetTrainerServiceInfo(i) }
  local name, rank, kind, icon = v[1], nil, nil, nil
  for j = 2, #v do
    local x = v[j]
    if type(x) == "string" and KINDS[x] and not kind then kind = x
    elseif type(x) == "string" and x ~= "" and not rank and not x:find("\\") then rank = x
    elseif (type(x) == "number" and x > 1000) or (type(x) == "string" and x:find("\\")) then icon = icon or x end
  end
  if GetTrainerServiceIcon then icon = GetTrainerServiceIcon(i) or icon end
  if rank and not rank:find("%d") then rank = nil end
  return name, rank, kind, icon
end
ns.ReadTrainerService = ReadService

function ns.ScanTrainer()
  if not GetNumTrainerServices then return end
  if IsTradeskillTrainer and IsTradeskillTrainer() then return end
  -- Show every spell for the read, then put your filters back.
  local old = {}
  for _, f in ipairs(FILTERS) do
    local ok, v = pcall(GetTrainerServiceTypeFilter, f)
    old[f] = (ok and v) and 1 or 0
    pcall(SetTrainerServiceTypeFilter, f, 1)
  end
  if ExpandTrainerSkillLine then pcall(ExpandTrainerSkillLine, 0) end
  local c = ns.Char()
  local skipped = {}
  if c.trainer then
    for _, sp in ipairs(c.trainer.spells) do if sp.skip then skipped[sp.name .. "|" .. (sp.rank or sp.lvl)] = true end end
  end
  local spells = {}
  for i = 1, GetNumTrainerServices() or 0 do
    local name, rank, kind, icon = ReadService(i)
    if name and kind and kind ~= "header" then
      local lvl = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
      spells[#spells + 1] = {
        name = name, rank = rank, lvl = lvl or 0, cost = GetTrainerServiceCost(i) or 0,
        used = kind == "used" or nil, skip = skipped[name .. "|" .. (rank or lvl or 0)],
        icon = icon,
      }
    end
  end
  for f, v in pairs(old) do pcall(SetTrainerServiceTypeFilter, f, v) end
  if #spells > 0 then
    table.sort(spells, function(a, b) if a.lvl ~= b.lvl then return a.lvl < b.lvl end return a.name < b.name end)
    c.trainer = { spells = spells, t = time() }
    ns.Changed()
  end
end

function ns.MarkTrained(name, rank)
  local t = ns.Char().trainer
  if not t then return end
  rank = (rank and rank ~= "") and rank or nil
  -- Without ranks (Forever), the lowest unlearned one by that name is it.
  for _, sp in ipairs(t.spells) do
    if sp.name == name and sp.rank == rank and not sp.used then sp.used = true; break end
  end
end

function ns.LevelUpReminder(lvl)
  local spells = ns.TrainingSpells()
  if not spells then return end
  local now = Tr.CostBy(spells, lvl)
  if now <= 0 then return end
  local b = ns.Bucket("training")
  local have = b and b.saved or 0
  ns.Print(("Level %d! Training is ready: %s. Your Training bucket has %s%s."):format(lvl, ns.Fmt(now, true), ns.Fmt(have, true),
    have < now and (" (|cffff6b6b" .. ns.Fmt(now - have) .. " short|r)") or ""))
end

---------------------------------------------------------------------------
-- Train my list: buy every spell that's ready now, except the ones you
-- skipped on the Training page. Only while a class trainer is open.
---------------------------------------------------------------------------
local function TrainerOpen()
  local w = ns.OpenWindows and ns.OpenWindows()
  return w and w.trainer == "training" and not w.trainerClosed
end
ns.TrainerOpen = TrainerOpen

-- What "Train my list" would buy: { { i, name, cost } }, total copper.
function ns.TrainPlan()
  local plan, total = {}, 0
  if not TrainerOpen() or not GetNumTrainerServices then return plan, 0 end
  local skipped = {}
  for _, sp in ipairs(ns.TrainingSpells() or {}) do
    if sp.skip then skipped[sp.name .. "|" .. (sp.rank or sp.lvl)] = true end
  end
  for i = 1, GetNumTrainerServices() or 0 do
    local name, rank, kind = ReadService(i)
    if name and kind == "available" then
      local lvl = GetTrainerServiceLevelReq and GetTrainerServiceLevelReq(i) or 0
      if not skipped[name .. "|" .. (rank or lvl)] then
        local cost = GetTrainerServiceCost(i) or 0
        plan[#plan + 1] = { i = i, name = name, cost = cost }
        total = total + cost
      end
    end
  end
  return plan, total
end

function ns.TrainMyList()
  local plan = ns.TrainPlan()
  if #plan == 0 then ns.Print("Nothing on your list to train right now."); return end
  local money, pick, cost = GetMoney(), {}, 0
  for _, s in ipairs(plan) do
    if cost + s.cost <= money then pick[#pick + 1] = s; cost = cost + s.cost end
  end
  if #pick < #plan then ns.Print(("You can afford %d of %d spells on your list."):format(#pick, #plan)) end
  -- Highest index first, so buying one doesn't shift the ones still to buy.
  table.sort(pick, function(a, b) return a.i > b.i end)
  for _, s in ipairs(pick) do BuyTrainerService(s.i) end
  if #pick > 0 then ns.Print(("Trained %d spell%s for %s."):format(#pick, #pick == 1 and "" or "s", ns.Fmt(cost, true))) end
end

-- A small bar at the top of the screen while the trainer is open.
local bar
local function Bar()
  if bar then return bar end
  local T = ns.T
  bar = CreateFrame("Frame", "BBBTrainBar", UIParent)
  bar:SetSize(420, 52); bar:SetFrameStrata("HIGH"); bar:SetClampedToScreen(true)
  bar:SetMovable(true); bar:EnableMouse(true); bar:RegisterForDrag("LeftButton")
  bar:SetScript("OnDragStart", bar.StartMoving)
  bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    ns.db.settings.trainBar = { x = x - ux, y = y - uy }
  end)
  T.Fill(bar, "BACKGROUND", 0.05, 0.05, 0.06, 0.95):SetAllPoints()
  T.Outline(bar, 1, 1, 1, 0.16)
  bar.icon = bar:CreateTexture(nil, "ARTWORK"); bar.icon:SetSize(30, 30); bar.icon:SetPoint("LEFT", 12, 0); bar.icon:SetTexture(ns.MEDIA .. "Icon")
  bar.title = T.Bold(bar, 12, T.TEXT); bar.title:SetPoint("TOPLEFT", bar.icon, "TOPRIGHT", 10, -1)
  bar.sub = T.Med(bar, 11, T.MUTED); bar.sub:SetPoint("BOTTOMLEFT", bar.icon, "BOTTOMRIGHT", 10, 1)
  bar.btn = T.Button(bar, "Train my list", 130, 30, function() ns.TrainMyList() end, true)
  bar.btn:SetPoint("RIGHT", -11, 0)
  bar:Hide()
  return bar
end

local function RefreshBar()
  if not TrainerOpen() then if bar then bar:Hide() end return end
  local b = Bar()
  local plan, total = ns.TrainPlan()
  local skippedNow = 0
  for _, sp in ipairs(ns.TrainingSpells() or {}) do
    if sp.skip and not sp.used and sp.lvl <= ns.Level() then skippedNow = skippedNow + 1 end
  end
  b.title:SetText(#plan == 0 and "Nothing on your list to train" or
    ("%d spell%s on your list   %s"):format(#plan, #plan == 1 and "" or "s", ns.Coins(total, 12)))
  b.sub:SetText(skippedNow > 0 and ("Skipping %d you marked on the Training page"):format(skippedNow) or "Skip spells on the BBB's Training page")
  b.btn:SetShown(#plan > 0)
  local pos = ns.db.settings.trainBar
  b:ClearAllPoints()
  if pos then b:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y) else b:SetPoint("TOP", UIParent, "TOP", 0, -140) end
  b:Show()
end
ns.RefreshTrainBar = RefreshBar

ns.OnChange(function() if bar and bar:IsShown() then RefreshBar() end end)

local tev = CreateFrame("Frame")
for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE" }) do pcall(tev.RegisterEvent, tev, e) end
tev:SetScript("OnEvent", function(_, event)
  if event == "TRAINER_CLOSED" then if bar then bar:Hide() end return end
  C_Timer.After(0.4, RefreshBar) -- after Capture's scan
end)
