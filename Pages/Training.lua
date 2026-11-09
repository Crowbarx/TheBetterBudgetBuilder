-- Training: every spell and rank your class trainer still has for you, grouped
-- by level with real prices. The Training bucket's goal follows your level:
-- what's ready now plus your next training level.
local _, ns = ...
local T, K, Tr = ns.T, ns.Kit, ns.Training

local page = { key = "training", order = 7, nav = "Training", title = "Training", subtitle = "Spells and ranks you haven't learned yet, up to level 60." }
table.insert(ns.Pages, page)

local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

function page.build(p)
  local c = p.child
  p.cards = { K.Card(c), K.Card(c), K.Card(c), K.Card(c) }
  p.empty = T.Med(c, 13, T.MUTED, "Visit your class trainer once. The BBB reads every spell up to level 60 and its real price, then the Training bucket's goal moves with you as you level.")
  p.empty:SetWordWrap(true)
  p.heads = ns.Pool(function(parent)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(30)
    T.Fill(h, "BACKGROUND", 1, 1, 1, 0.05):SetAllPoints()
    h.edge = T.Fill(h, "ARTWORK", 1, 1, 1, 1); h.edge:SetWidth(3)
    h.edge:SetPoint("TOPLEFT"); h.edge:SetPoint("BOTTOMLEFT")
    h.text = T.Bold(h, 13); h.text:SetPoint("LEFT", 16, 0)
    h.tag = T.Bold(h, 9, T.MUTED); h.tag:SetPoint("LEFT", h.text, "RIGHT", 12, 0)
    h.cost = T.Med(h, 11, T.MUTED); h.cost:SetPoint("RIGHT", -14, 0); h.cost:SetJustifyH("RIGHT")
    return h
  end)
  p.rows = ns.Pool(function(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(32)
    T.Fill(r, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
    r.hl = T.Fill(r, "HIGHLIGHT", 1, 1, 1, 0.05); r.hl:SetAllPoints()
    r.icon = T.Icon(r, 24); r.icon:SetPoint("LEFT", 14, 0)
    r.name = T.Bold(r, 12); r.name:SetPoint("LEFT", r.icon, "RIGHT", 12, 0)
    r.rank = T.Med(r, 11, T.MUTED); r.rank:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.cost = T.Bold(r, 12); r.cost:SetPoint("RIGHT", -14, 0); r.cost:SetJustifyH("RIGHT")
    r.tag = T.Bold(r, 9, T.MUTED); r.tag:SetPoint("RIGHT", r.cost, "LEFT", -16, 0)
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.sp.name .. (self.sp.rank and ("  |cff9a9aa0" .. self.sp.rank .. "|r") or ""), 1, 1, 1)
      GameTooltip:AddLine(self.sp.skip and "Skipped: not counted in your goal. Click to count it again."
        or "Click to skip it if you don't plan to train it.", 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
  end)
  p.footText = T.Med(p.footFrame, 12, T.TEXT); p.footText:SetPoint("LEFT", 2, 0)
  p.footHint = T.Med(p.footFrame, 11, T.MUTED); p.footHint:SetPoint("LEFT", p.footText, "RIGHT", 24, 0)
  p.trainBtn = T.Button(p.footFrame, "Train my list", 140, 34, function() ns.TrainMyList() end, true)
  p.trainBtn:SetPoint("RIGHT", -112, 0)
end

-- Spells you still need, grouped by level: { { lvl, ready, spells, cost } }.
local function Groups(spells, level)
  local groups, byKey = {}, {}
  for _, sp in ipairs(spells) do
    if not sp.used then
      local ready = sp.lvl <= level
      local key = ready and 0 or sp.lvl
      local g = byKey[key]
      if not g then g = { lvl = key, ready = ready, spells = {}, cost = 0 }; byKey[key] = g; groups[#groups + 1] = g end
      g.spells[#g.spells + 1] = sp
      if not sp.skip then g.cost = g.cost + (sp.cost or 0) end
    end
  end
  table.sort(groups, function(a, b) return a.lvl < b.lvl end)
  return groups
end

function page.refresh(p)
  local c = p.child
  local spells = ns.TrainingSpells()
  local level = ns.Level()
  local tb = ns.Bucket("training")
  local have = tb and tb.saved or 0
  for _, card in ipairs(p.cards) do card:SetShown(spells ~= nil) end
  p.empty:SetShown(not spells)
  p.heads:Reset(); p.rows:Reset()
  if not spells then
    p.empty:ClearAllPoints(); p.empty:SetPoint("TOPLEFT", 2, 0); p.empty:SetPoint("RIGHT", c, "RIGHT")
    p.footText:SetText(""); p.footHint:SetText(""); p.trainBtn:Hide()
    return 60
  end
  local now, readyList = Tr.CostBy(spells, level)
  local nextLvl, nextCost = Tr.NextLevel(spells, level)
  local goal = Tr.Goal(spells, level) or 0
  p.cards[1]:Set("Available now", ns.Coins(now, 15), now > 0 and (#readyList .. " ready to train") or "Nothing to train", now > 0 and T.WARN or T.TEXT, true)
  p.cards[2]:Set(nextLvl and ("Level " .. nextLvl) or "Next level", ns.Coins(nextCost, 15), nextLvl and "Your next new spells" or "Nothing left to learn")
  p.cards[3]:Set("Training bucket", ns.Coins(have, 15), "Goal " .. ns.Fmt(goal))
  local short = goal - have
  p.cards[4]:Set(short > 0 and "Still to save" or "Covered", ns.Coins(math.max(0, short), 15), short > 0 and "For your goal" or "You're set", short > 0 and T.BAD or T.GOOD)
  local y = K.Columns(p.cards, c, 0, 8, 78) + 18

  local a = T.Accent()
  for _, g in ipairs(Groups(spells, level)) do
    local h = p.heads:Get(c)
    h:SetPoint("TOPLEFT", 0, -y); h:SetPoint("RIGHT", c, "RIGHT")
    local col = g.ready and T.GOOD or T.GOLD
    h.text:SetText(g.ready and "Available now" or ("Level " .. g.lvl))
    h.text:SetTextColor(col[1], col[2], col[3])
    h.edge:SetColorTexture(col[1], col[2], col[3], 0.9)
    local inGoal = g.ready or g.lvl == nextLvl
    h.tag:SetText(inGoal and "IN YOUR GOAL" or "")
    h.tag:SetTextColor(a[1], a[2], a[3])
    h.cost:SetText(#g.spells .. (#g.spells == 1 and " spell" or " spells") .. "   " .. ns.Coins(g.cost, 11))
    y = y + 32
    for _, sp in ipairs(g.spells) do
      local r = p.rows:Get(c)
      r.sp = sp
      r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
      r.icon:SetTexture(sp.icon or QUESTION)
      r.name:SetText(sp.name)
      r.rank:SetText((sp.rank and sp.rank:find("%d")) and sp.rank or "")
      r.cost:SetText(ns.Coins(sp.cost, 11))
      r.tag:SetText(sp.skip and "SKIPPED" or "")
      r:SetAlpha(sp.skip and 0.4 or (inGoal and 1 or 0.75))
      r:SetScript("OnClick", function() sp.skip = not sp.skip or nil; ns.Changed() end)
      y = y + 34
    end
    y = y + 10
  end
  p.footText:SetText(("Available now: %d   |   Cost: %s"):format(#readyList, ns.Coins(now, 12)))
  p.trainBtn:SetShown(ns.TrainerOpen() and #(ns.TrainPlan()) > 0)
  p.footHint:SetText(("Scanned %s  ·  click a spell to skip it; Train my list leaves it out"):format(K.Date(ns.Char().trainer.t)))
  return y + 8
end
