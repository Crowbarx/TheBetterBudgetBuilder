-- Buckets: your named savings piles.
local _, ns = ...
local T, K, Bk = ns.T, ns.Kit, ns.BucketMath

local page = { key = "buckets", order = 5, nav = "Buckets", title = "Buckets", subtitle = "Savings piles. Gold in a bucket isn't safe to spend." }
table.insert(ns.Pages, page)


local function Edit(b, what)
  if what == "rename" then
    ns.Ask("Name this bucket:", b.name, function(t) if t and t ~= "" then b.name = t; ns.Changed() end end)
  elseif what == "goal" then
    if b.auto == "training" then ns.Print("The Training goal comes from your trainer's prices."); return end
    ns.AskMoney(("Goal for %s (e.g. 1000, 250g, or 0 for none):"):format(b.name), b.target and ns.Fmt(b.target) or "",
      function(v) b.target = v > 0 and v or nil; ns.Changed() end)
  elseif what == "pct" then
    local others = 0
    for _, x in ipairs(ns.Buckets()) do if x ~= b then others = others + (x.pct or 0) end end
    ns.Ask(("What %% of every copper you earn goes into %s?\n(other buckets take %d%%)"):format(b.name, others), tostring(b.pct or 0), function(t)
      local v = tonumber((t or ""):match("%d+"))
      if not v then return end
      b.pct = math.max(0, math.min(100 - others, v))
      if v > 100 - others then ns.Print("Capped at " .. b.pct .. "% so all buckets stay at or under 100%.") end
      ns.Changed()
    end)
  elseif what == "level" then
    ns.Ask(("By what level do you want %s? (0 for none)"):format(b.name), tostring(b.dueLevel or ""), function(t)
      local v = tonumber((t or ""):match("%d+"))
      b.dueLevel = (v and v > 0) and v or nil
      ns.Changed()
    end)
  elseif what == "icon" then
    ns.PickIcon(b.icon, function(v) b.icon = v; ns.Changed() end)
  elseif what == "up" or what == "down" then
    local list = ns.Buckets()
    for i, x in ipairs(list) do
      if x == b then
        local j = i + (what == "up" and -1 or 1)
        if list[j] then list[i], list[j] = list[j], list[i] end
        break
      end
    end
    ns.Changed()
  elseif what == "pause" then
    b.paused = not b.paused or nil
    ns.Changed()
  elseif what == "delete" then
    ns.Confirm(("Delete %s? Its %s becomes safe to spend."):format(b.name, ns.Fmt(b.saved, true)), function()
      for i, x in ipairs(ns.Buckets()) do if x == b then table.remove(ns.Buckets(), i); break end end
      ns.Changed()
    end)
  end
end

function page.build(p)
  local c = p.child
  p.cards = ns.Pool(function(parent)
    local r = T.Panel(parent, true)
    r:SetHeight(104)
    r.icon = T.Icon(r, 40); r.icon:SetPoint("TOPLEFT", 18, -18)
    r.iconBtn = CreateFrame("Button", nil, r); r.iconBtn:SetAllPoints(r.icon)
    r.name = T.Bold(r, 15); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 14, -2)
    r.sub = T.Med(r, 11); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -6)
    r.value = T.Bold(r, 15); r.value:SetPoint("TOPRIGHT", -18, -18); r.value:SetJustifyH("RIGHT")
    r.goal = T.Med(r, 11); r.goal:SetPoint("TOPRIGHT", r.value, "BOTTOMRIGHT", 0, -6); r.goal:SetJustifyH("RIGHT")
    r.name:SetPoint("RIGHT", r.value, "LEFT", -12, 0)
    r.bar = T.Bar(r, 4)
    r.bar.track:SetPoint("TOPLEFT", 72, -66); r.bar.track:SetPoint("TOPRIGHT", -18, -66)
    r.add = T.Button(r, "Add gold", 100, 24, function() end)
    r.add:SetPoint("BOTTOMLEFT", 72, 10)
    r.take = T.Button(r, "Take out", 100, 24, function() end)
    r.take:SetPoint("LEFT", r.add, "RIGHT", 6, 0)
    r.edit = T.Button(r, "Edit" .. T.CARET, 90, 24, function() end)
    r.edit:SetPoint("LEFT", r.take, "RIGHT", 6, 0)
    return r
  end)
  p.newBtn = T.Button(p.footFrame, "+ New bucket", 160, 34, function()
    ns.Ask("Name the new bucket (e.g. Riding skill, Bags, BoE sword):", "", function(t)
      if not t or t == "" then return end
      table.insert(ns.Buckets(), { id = "b" .. time() .. math.random(100, 999), name = t, icon = "Interface\\Icons\\INV_Misc_Bag_10_Blue", saved = 0, pct = 0 })
      ns.Changed()
    end)
  end)
  p.newBtn:SetPoint("LEFT")
  p.fillBtn = T.Button(p.footFrame, "Fill to goals", 150, 34, function()
    local moved = Bk.FillAll(ns.Buckets(), math.max(0, ns.Safe()), ns.Goal)
    ns.Print(moved > 0 and ("Moved " .. ns.Fmt(moved, true) .. " into your buckets.") or "Nothing to move.")
    ns.Changed()
  end)
  p.fillBtn:SetPoint("LEFT", p.newBtn, "RIGHT", 10, 0)
  p.summary = T.Med(p.child, 12, T.MUTED)
end

function page.refresh(p)
  local c = p.child
  local level = UnitLevel("player") or 1
  local totalPct = 0
  for _, b in ipairs(ns.Buckets()) do totalPct = totalPct + (b.pct or 0) end
  p.summary:ClearAllPoints(); p.summary:SetPoint("TOPLEFT", 2, 0); p.summary:SetPoint("RIGHT", c, "RIGHT")
  p.summary:SetWordWrap(true)
  p.summary:SetText(("Every copper you earn: %d%% goes into buckets until they hit their goals, the rest is safe to spend. " ..
    "Spending comes out of safe gold first; a buy that needs more dips into buckets from the bottom of this list up, so keep what matters most on top."):format(totalPct))
  local y = p.summary:GetStringHeight() + 18
  p.cards:Reset()
  for i, b in ipairs(ns.Buckets()) do
    local r = p.cards:Get(c)
    r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", c, "RIGHT")
    r.icon:SetTexture(b.icon)
    r.name:SetText(b.name .. (b.paused and "  |cff9a9aa0(paused)|r" or ""))
    local goal = ns.Goal(b)
    local bits = {}
    bits[#bits + 1] = (b.pct or 0) > 0 and ((b.pct) .. "% of income") or "Filled by hand"
    if b.auto == "training" then bits[#bits + 1] = goal and "goal follows your level: ready now + next level" or "visit your trainer once to set the goal" end
    if b.dueLevel then
      local per = goal and Bk.PerLevel(b, level, goal)
      bits[#bits + 1] = "by level " .. b.dueLevel .. (per and b.saved < (goal or 0) and (" (" .. ns.Fmt(per) .. " per level)") or "")
    end
    r.sub:SetText(table.concat(bits, "   ·   "))
    r.value:SetText(ns.Coins(b.saved, 14))
    if goal then
      r.goal:SetText(b.saved >= goal and "|cff6bd999Goal reached|r" or (ns.Fmt(goal - b.saved) .. " to go of " .. ns.Fmt(goal)))
    else
      r.goal:SetText("No goal")
    end
    r.bar:Set(goal and goal > 0 and b.saved / goal or 0, goal and b.saved >= goal and T.GOOD or nil)
    r.add:SetScript("OnClick", function()
      local safe = math.max(0, ns.Safe())
      local suggest = goal and math.min(math.max(0, goal - b.saved), safe) or nil
      ns.AskMoney(("Move how much into %s?\n(%s is safe to spend)"):format(b.name, ns.Fmt(safe)), suggest and suggest > 0 and ns.Fmt(suggest) or "", function(v)
        local give = math.min(v, safe)
        if give < v then ns.Print("Only " .. ns.Fmt(give, true) .. " was safe to move.") end
        b.saved = b.saved + give
        ns.Changed()
      end)
    end)
    r.take:SetScript("OnClick", function()
      ns.AskMoney(("Take how much out of %s (%s)?"):format(b.name, ns.Fmt(b.saved)), ns.Fmt(b.saved), function(v)
        b.saved = math.max(0, b.saved - v)
        ns.Changed()
      end)
    end)
    r.edit:SetScript("OnClick", function(self)
      local ch = {
        { value = "rename", text = "Rename" },
        { value = "icon", text = "Change icon" },
        { value = "pct", text = "Auto-fill %" },
      }
      if b.auto ~= "training" then ch[#ch + 1] = { value = "goal", text = "Goal amount" } end
      ch[#ch + 1] = { value = "level", text = "Goal level" }
      ch[#ch + 1] = { value = "pause", text = b.paused and "Resume auto-fill" or "Pause auto-fill" }
      if i > 1 then ch[#ch + 1] = { value = "up", text = "Move up" } end
      if i < #ns.Buckets() then ch[#ch + 1] = { value = "down", text = "Move down" } end
      ch[#ch + 1] = { value = "delete", text = "|cffff6b6bDelete|r" }
      T.Menu(self, ch, nil, function(v) Edit(b, v) end)
    end)
    r.iconBtn:SetScript("OnClick", function() Edit(b, "icon") end)
    y = y + 112
  end
  return y
end
